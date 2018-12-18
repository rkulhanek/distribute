import std.stdio, std.socket, core.thread, std.file, std.exception, std.conv, std.typecons, std.string, std.regex;
import std.file, std.random, std.parallelism, std.process, std.getopt;
import core.sys.posix.stdlib;

import util;

shared string IP;
const uint PORT = 8004;
shared string command;
uint tid;

alias WorkUnit = Tuple!(string, "name", ubyte[], "data");

auto connect() {
	Socket conn = new Socket(AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
	writef("IP = %s:%s\n", IP, PORT);
	auto addr = parseAddress(IP, PORT);

	uint count = 0;
	while (null !is collectException(conn.connect(addr))) {
		msleep(100);
		count++;
		if (count > 100) {
			throw new Exception("Cannot connect to server");
		}
	}
	return conn;
}

auto getFile() {
	auto conn = connect();
	scope(exit) conn.close();

	conn.sendPacket("GET".representation);
	auto status = conn.recvPacket;
	if ("ok" != status) return null;

	string fname = conn.recvPacket.assumeUTF;
	auto contents = conn.recvPacket;

	return new WorkUnit(fname, contents);
}

//not worried about race conditions here.
//TODO: write a function that does everything necessary to make this safe. umask, O_CREAT, O_EXCL, etc.
auto tmpFile(string prefix) {
	//random start point to hopefully find an unused name the first try
	foreach (i; 0..10000) {
		string fname = prefix ~ format(".%06x", uniform!"[]"(0, 0xFFFFFF));
		if (!exists(fname)) return File(fname, "wb");
	}

	//exhaustive search to guarantee success if possible
	foreach (suffix; 0..0xFFFFFF) {
		string fname = prefix ~ format(".%06x", suffix);
		if (!exists(fname)) return File(fname, "wb");
	}

	//And apparently we have over 16 million temporary files in this directory.
	throw new Exception("Could not create new tmpfile");
}

//TODO: command should be passed via getopt. Any instances of $FILE will be replaced by
//the filename.

void sendResult(string name, int status, File stdout, File stderr) {
	auto conn = connect();
	scope(exit) conn.close();

	if (0 == status) {
		conn.sendPacket(format("RESULT %s", name));
	}
	else {
		conn.sendPacket(format("ERROR %s", name));
		//conn.sendPacket(format("status %s\n", status).representation);
	}
	writef("# sendResult for %s\n", name);
	writef("status: %s\n", status);

	void sendFile(File f) {
		ubyte[] readAll(File f) {
			ubyte[] all;
			ubyte[1024] buf;
			while (!f.eof) {
				auto tmp = f.rawRead(buf);
				writef("read %s bytes\n", tmp.length);
				all ~= tmp;
			}
			return all;
		}

		auto buf = readAll(f);
		writef("%s\n", buf.assumeUTF);
		conn.sendPacket(buf);
	}

	sendFile(stdout);
	sendFile(stderr);
}

void worker(uint thread_id) {
	tid = thread_id;
	writef("thread %s start\n", tid);
	msleep(uniform(0, 1000));//avoid having every client clobbering the server at exactly the same time.

	void test(uint i) {
		stderr.writef("test %s-%s\n", tid, i);
	}

	while (1) {
		test(0);
		auto packet = getFile();
		test(1);
		if (packet is null) {
			test(2);
			writef("Thread %s terminated\n", tid);
			break;
		}
		test(3);
		writef("thread %s : start %s\n", tid, packet.name);
		auto input = tmpFile(tempDir() ~ "/workunit");
		input.rawWrite(packet.data);//TODO: this is in text mode, not binary. Do something about that.
		input.flush();

		writef("input file: %s\n", input.name);
		
		auto cmd = command.replaceAll(ctRegex!`\$FILE`, input.name);
		writef("cmd = '%s'\n", cmd);
//		auto pipes = cmd.pipeShell(Redirect.all);
		auto pipes = pipeProcess([ "./run.sh", input.name ]);
		auto status = pipes.pid.wait();

		//sendResult(packet.name, result.output);
		sendResult(packet.name, status, pipes.stdout, pipes.stderr);
		
		writef("thread %s : finish %s\n", tid, packet.name);
	}
	writef("thread %s exit\n", tid);
}

int main(string[] argv) {
	//Any instance of $FILE will be replaced by the filename it operates on
	string cmd = "./run.sh '$FILE'";
	string ip = "0.0.0.0";

	auto opt = getopt(argv,
		//std.getopt.config.required, "indir", &indir,
		std.getopt.config.required, "server-ip", &ip,
		std.getopt.config.required, "command", &cmd,
	);
	command = cmd;
	IP = ip;
	if (opt.helpWanted) {
		defaultGetoptPrinter(format("Usage: %s --server-ip IP --command COMMAND\n", argv[0]), opt.options);
		return 1;
	}
	writef("IP: %s\n", IP);

	auto nThreads = 1;//totalCPUs;
	
	foreach (i; 0..nThreads) {
		task!worker(i).executeInNewThread;
	}
	worker(64);
	return 0;
/+
	{
		writef("%s\n", a.name);
		//TODO: not loop. per-thread

		string aname = (cast(immutable(char)*)a.name)[0..a.name.length];
		writef("%s\n", aname);
		writef("%s: %s\n", a.name, a.data);
		writef("recv bar\n");
		auto b = getFile();
		if (b is null) return;
		writef("%s: %s\n", b.name, b.data);
	}
	auto f = tmpFile("foobar");
	f.writef("foobar\n");
	return;+/
}

