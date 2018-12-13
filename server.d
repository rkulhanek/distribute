import std.stdio, std.socket, core.thread, std.file, std.string;
import util;

const uint PORT = 8004;

string[] queue;
string[] completed;
bool[string] in_progress;
	
void send_file(Socket conn, string fname) {
	writef("send_file(%s)\n", fname);
	conn.sendPacket(fname.representation);
	auto buf = cast(const ubyte[])read(fname);
	conn.sendPacket(buf);
}

void send_terminate(Socket conn) {
	//TODO: 
}

void send_string_array(Socket conn, const string[] arr) {
	//TODO:
}

void main() {
	Socket server, conn;

	server = new Socket(AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
	scope(exit) server.close();
	server.bind(new InternetAddress(InternetAddress.ADDR_ANY, PORT));
	server.listen(64);
	writef("listening\n");

	//TODO: getopt

	foreach (i; 0..32) {
		queue ~= "foo";
		queue ~= "bar";
	}

	while (queue.length + in_progress.length > 0) {
		try {
			conn = server.accept();
			scope(exit) conn.close();

			auto request = conn.recvPacket();
			bool prefix(string s) {
				return request.length >= s.length && request[0..s.length] == s;
			}
			if (prefix("GET")) {//GET : client requests work unit
				if (queue.length) {
					conn.send_file(queue[0]);
					in_progress[queue[0]] = 1;
					queue  = queue[1..$];
				}
				else {
					conn.send_terminate();
				}
			}
			else if (prefix("PUT")) {//PUT name : client is returning results for work unit name
				//TODO: write file to results direcotry
				auto name = (cast(immutable(char)*)request)[4..request.length];
				in_progress.remove(name);
				completed ~= name;
			}
			else if (prefix("STATUS")) {
				//fetch the queue/in_progress/completed sets
				conn.send_string_array(queue);
				conn.send_string_array(in_progress.keys);//will need to convert back to associative array on clientside
				conn.send_string_array(completed);
			}
			
			//conn.send_file(files[0]);
			//files = files[1..$];
		}
		catch (Exception e) {
			stderr.writef("%s\n", e.msg);
			//TODO: also print network error
		}
	}

	//TODO: will reach this point before all clients have received a terminate.
	//have it accept here for another minute or so to clean up remaining clients.
	//should probably just be the last one to submit its results.
	//And clients can terminate if they have N failed attempts to connect to the server.

	//Alternately, maintain a list of active clients, and they need to log out officially before they stop making
	//requests.  If I do this, in_progress should be string[string], and map to the client's host name.
}

