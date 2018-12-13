import std.stdio, std.socket, core.thread, std.file, std.exception, std.conv, std.typecons, std.string, std.regex;
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
	while (null !is collectException(conn.connect(addr))) {
		msleep(100);
	}

	conn.sendPacket("GET".representation);
	auto fname = conn.recvPacket.to!string;
	auto contents = conn.recvPacket;

	return WorkUnit(fname, contents);
}

auto tmpFile(string prefix) {
	auto s = prefix ~ "XXXXXX";
	char[] fname_template = s.toStringz[0..s.length].dup;

	int fd = mkstemp(fname_template.ptr);
	write(fd, "foo\n", 4);
	auto f = File("/dev/stderr", "wb");
	try {
		writef("test 0\n");
		f.fdopen(fd);
		writef("test 1\n");
		f.writef("foobar1\n");
		return f;
	}
	catch (Exception e) {
		writef("%s\n", e.msg);
	}
	assert(0);
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

		string aname = (cast(immutable(char)*)a.name)[0..a.name.length];
		writef("%s\n", aname);
		writef("%s: %s\n", a.name, a.data);
		writef("recv bar\n");
		auto b = getFile();
		writef("%s: %s\n", b.name, b.data);
	}
	auto f = tmpFile("foobar");
	f.writef("foobar\n");
	return;
}

