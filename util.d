import std.socket, std.bitmanip, std.exception;
import std.stdio;

extern(C) {
	int usleep(uint);
}

void msleep(uint msec) {
	usleep(msec * 1000);
}

auto sendPacket(Socket conn, const ubyte[] buf) {
	ubyte[ulong.sizeof] len = nativeToLittleEndian(buf.length);
	//enforce(len.length == conn.send(len));
	auto n = conn.send(len);
	if (len.length != n) {
		writef("%s != %s : %s\n%s\n", len.length, n, conn.getErrorText, lastSocketError());
		assert(0);
	}

//	writef("send %s: '%s'\n", buf.length, buf);
	n = conn.send(buf);
	if (buf.length != n) {
		writef("%s != %s : %s\n%s\n", buf.length, n, conn.getErrorText, lastSocketError());
		assert(0);
		//enforce(buf.length == conn.send(buf));
	}
}

auto recvPacket(Socket conn) {
	ubyte[] buf;
	ubyte[ulong.sizeof] len;
//	writef("recv %s\n", len.length);
	conn.receive(len);
	buf.length = littleEndianToNative!ulong(len);
//	writef("recv %s\n", buf.length);
	enforce(buf.length == conn.receive(buf));
	return buf;
}

