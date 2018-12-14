import std.socket, std.bitmanip, std.exception, std.format, std.conv;
import std.stdio;

extern(C) {
	int usleep(uint);
}

void msleep(uint msec) {
	usleep(msec * 1000);
}

auto sendPacket(Socket conn, const ubyte[] buf) {
	void sendAux(const ubyte[] buf) {
		ulong totalSent = 0;
		while (totalSent < buf.length) {
			auto n = conn.send(buf[totalSent..$]);
			if (n < 0) {
				throw new Exception(format("sendPacket failed: %s\n%s", conn.getErrorText, lastSocketError));
			}
			totalSent += n;
		}
	}

	ubyte[ulong.sizeof] len = nativeToLittleEndian(buf.length);
	sendAux(len);
	sendAux(buf);
}

auto recvPacket(Socket conn) {
	auto recvAux(ulong length) {
		ubyte[] buf;
		buf.length = length;

		ulong totalReceived = 0;
		while (totalReceived < length) {
			auto n = conn.receive(buf[totalReceived..$]);
			if (n < 0) {
				throw new Exception(format("recvPacket Failed: %s\n%s", conn.getErrorText, lastSocketError));
			}
			totalReceived += n;
		}

		return buf;
	}

	auto len = recvAux(ulong.sizeof)
		.to!(ubyte[ulong.sizeof])
		.littleEndianToNative!(ulong, ulong.sizeof);
	return recvAux(len);
}

