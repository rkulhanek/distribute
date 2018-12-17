import std.stdio, std.socket, core.thread, std.file, std.string, std.getopt;
import core.sys.posix.signal, core.sys.posix.stdlib, std.regex, std.path;
import util;
import std.utf;

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
	string s = cast(string)(buf).toUTF8;
	return s;
}

void send_file(Socket conn, string fname) {
	conn.sendPacket("ok".representation);
	conn.sendPacket(fname.representation);
	auto buf = cast(const ubyte[])read(fname);
	conn.sendPacket(buf);
}

void send_terminate(Socket conn) {
	conn.sendPacket("terminate".representation);
}
/+
void send_string_array(Socket conn, const string[] arr) {
	//TODO:
}+/

int main(string[] argv) {
	string outdir;
	auto opt = getopt(argv,
		//std.getopt.config.required, "indir", &indir,
		std.getopt.config.required, "outdir", &outdir,
	);
	if (opt.helpWanted) {
		defaultGetoptPrinter(format("Usage: %s [flags] filelist\n", argv[0]), opt.options);
		return 1;
	}
	queue = argv[1..$];

	mkdirRecurse(outdir);

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
				auto name = (cast(immutable(char)*)request)[6..request.length];
				writef("recv from %s: %s\n", hostname, name);
				//TODO: store in results directory

				auto data = conn.recvPacket();
				//TODO: if file name has directory components, remove them. Or make those directories UNDER outdir
				File(outdir ~ "/" ~ name.baseName, "wb").write(data);
				
				in_progress.remove(name);
				completed ~= name;
			}
			else if (prefix("ERROR")) {//ERROR name : details of error in packet
				auto name = (cast(immutable(char)*)request)[6..request.length];
				stderr.writef("error reported from %s: %s\n%s\n", hostname, name.stringify, cast(string)(conn.recvPacket()));
				stderr.writef("error reported from %s: %s\n%s\n", hostname, name.stringify, conn.recvPacket());
				stderr.flush();

				in_progress.remove(name);
				failed ~= name;
				//TODO: include stderr in packet
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
			
			//conn.send_file(files[0]);
			//files = files[1..$];
		}
		catch (Exception e) {
			stderr.writef("%s\n", e.msg);
			//TODO: also print network error
		}
	}

	writef("Failed: %s\n", failed);

	//TODO: will reach this point before all clients have received a terminate.
	//have it accept here for another minute or so to clean up remaining clients.
	//should probably just be the last one to submit its results.
	//And clients can terminate if they have N failed attempts to connect to the server.

	//Alternately, maintain a list of active clients, and they need to log out officially before they stop making
	//requests.  If I do this, in_progress should be string[string], and map to the client's host name.
	return 0;
}

