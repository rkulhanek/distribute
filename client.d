import std.stdio, std.socket, core.thread, std.file, std.exception, std.conv, std.typecons, std.string, std.regex;
import std.file, std.random;
import core.sys.posix.stdlib;

import util;

string IP = "127.0.0.1";
const uint PORT = 8004;

string[] buffer;

alias WorkUnit = Tuple!(string, "name", ubyte[], "data");

auto getFile() {
	Socket conn = new Socket(AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
	scope(exit) conn.close();
	auto addr = parseAddress(IP, PORT);

	uint count = 0;
	while (null !is collectException(conn.connect(addr))) {
		msleep(100);
		count++;
		if (count > 100) {
			throw new Exception("Cannot connect to server");
		}
	}

	conn.sendPacket("GET".representation);
	auto status = conn.recvPacket;
	if ("ok" != status) return null;

	auto fname = conn.recvPacket.to!string;
	auto contents = conn.recvPacket;

	return new WorkUnit(fname, contents);
}

/+
auto tmpFile(string prefix) {
	auto s = prefix ~ "XXXXXX";
	char[] fname_template = s.toStringz[0..s.length].dup;

	int fd = mkstemp(fname_template.ptr);
	auto f = File("/dev/stderr", "wb");
	try {
		writef("test 0\n");
		f.fdopen(fd);
		writef("test 1\n");
		f.writef("foobar1\n");
		writef("test 2\n");
		return f;
	}
	catch (Exception e) {
		writef("%s\n", e.msg);
	}
	assert(0);
}
+/

//not worried about race conditions here.
//TODO: write a function that does everything necessary to make this safe. umask, O_CREAT, O_EXCL, etc.
auto tmpFile(string prefix) {
	while (1) {
		string fname = prefix ~ format(".%06x", uniform!"[]"(0, 0xFFFFFF));
		if (!exists(fname)) return File(fname, "wb");
	}
}

//TODO: cmd should be passed via getopt. Any instances of $FILE will be replaced by
//the filename.
void processWorkUnit(WorkUnit wu, string cmd) {
	auto fname = wu.name;
	cmd = cmd.replaceAll(ctRegex!`\$FILE`, fname);
}

void main() {
	foreach (i; 0..2) {
		writef("iter %s\n", i);
		writef("recv foo\n");
		auto a = getFile();
		if (a is null) return;

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
	return;
}

