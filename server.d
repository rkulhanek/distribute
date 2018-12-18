import std.stdio, std.socket, core.thread, std.file, std.string, std.getopt;
import core.sys.posix.signal, core.sys.posix.stdlib, std.regex, std.path;
import std.utf, std.algorithm, std.conv, std.array;
import util;

const uint PORT = 8004;

string[] queue;
string[] completed;
string[] failed;
bool[string] in_progress;

Socket server;

extern(C) {
	void cleanup(int s) nothrow @nogc @system {
		try {
			server.close();
			printf("Cleanup\n");
			exit(0);
		}
		catch (Exception e) {}
	}
}

string stringify(T)(T buf) {
	string s;
	import std.ascii;
	foreach (i, x; buf) {
		char c = x;
		if (!isPrintable(c) && !isWhite(c)) {
			writef("Unprintable char: %c -> %x\n", c, c);
		}
		s ~= c;
	}
	writef("stringify(%s [%s]) -> %s [%s]\n", buf, typeid(buf), s, typeid(s));
	return s;
}

void send_file(Socket conn, string fname) {
	conn.sendPacket("ok");
	conn.sendPacket(fname);
	auto buf = cast(const ubyte[])read(fname);
	conn.sendPacket(buf);
}

void send_terminate(Socket conn) {
	conn.sendPacket("terminate");
}

void summary() {
	auto total = queue.length + in_progress.length + failed.length + completed.length;
	writef("Queue: %s/%s  In Progress: %s   Completed: %s/%s   Failed: %s\n", 
		queue.length, total, in_progress.length, completed.length, total, failed.length);
}

int main(string[] argv) {
	string outdir;
	auto opt = getopt(argv,
		std.getopt.config.required, "outdir", &outdir,
	);
	if (opt.helpWanted) {
		defaultGetoptPrinter(format("Usage: %s [flags] filelist\n", argv[0]), opt.options);
		return 1;
	}
	queue = argv[1..$];

	mkdirRecurse(outdir ~ "/failures");

	Socket conn;

	server = new Socket(AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
	scope(exit) server.close();
	server.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
	signal(SIGINT, &cleanup);
	server.bind(new InternetAddress(InternetAddress.ADDR_ANY, PORT));
	server.listen(64);
	writef("listening\n");

	while (queue.length + in_progress.length > 0) {
		try {
			conn = server.accept();
			scope(exit) conn.close();

			auto request = conn.recvPacket();

			auto hostname = conn.remoteAddress.toHostNameString;
			if (hostname is null) hostname = conn.remoteAddress.toAddrString;

			bool prefix(string s) {
				return request.length >= s.length && request[0..s.length] == s;
			}

			if (prefix("GET")) {//GET : client requests work unit
				if (queue.length) {
					writef("send to %s: %s\n", hostname, queue[0]);
					conn.send_file(queue[0]);
					in_progress[queue[0]] = 1;
					queue  = queue[1..$];
				}
				else {
					conn.send_terminate();
				}
			}
			else if (prefix("RESULT")) {//RESULT name : client is returning results for work unit name
				//TODO: write file to results direcotry
				//auto name = (cast(immutable(char)*)request)[6..request.length];
				string name = request[7..request.length].assumeUTF;

				writef("recv from %s: %s\n", hostname, name);
				File(outdir ~ "/" ~ name.baseName ~ ".stdout", "wb").rawWrite(conn.recvPacket);
				File(outdir ~ "/" ~ name.baseName ~ ".stderr", "wb").rawWrite(conn.recvPacket);
				
				in_progress.remove(name);
				completed ~= name;
			}
			else if (prefix("ERROR")) {//ERROR name : details of error in packet
				string name = request[6..request.length].assumeUTF;
				auto packet = conn.recvPacket();

				writef("error reported from %s: %s\n%s\n", hostname, name, packet.assumeUTF);
				File(outdir ~ "/failures/" ~ name.baseName ~ ".stdout", "wb").rawWrite(conn.recvPacket);
				File(outdir ~ "/failures/" ~ name.baseName ~ ".stderr", "wb").rawWrite(conn.recvPacket);

				in_progress.remove(name);
				failed ~= name;
			}
/+			else if (prefix("STATUS")) {
				//fetch the queue/in_progress/completed sets
				conn.send_string_array(queue);
				conn.send_string_array(in_progress.keys);//will need to convert back to associative array on clientside
				conn.send_string_array(completed);
			}+/
			else {
				stderr.writef("ERROR: unknown packet type; %s\n", request);
			}
			summary();
		}
		catch (Exception e) {
			stderr.writef("%s\n", e.msg);
			//TODO: also print network error
		}
	}

	if (failed.length) {
		writef("# Failed work units\n");
		foreach (s; failed) {
			writef("%s\n", s);
		}
	}

	//TODO: will reach this point before all clients have received a terminate.
	//have it accept here for another minute or so to clean up remaining clients.
	//should probably just be the last one to submit its results.
	//And clients can terminate if they have N failed attempts to connect to the server.

	//Alternately, maintain a list of active clients, and they need to log out officially before they stop making
	//requests.  If I do this, in_progress should be string[string], and map to the client's host name.
	return 0;
}

