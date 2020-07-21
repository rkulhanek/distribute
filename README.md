This is a simple framework for distributing work across multiple systems.
The goal is simplicity and robustness. Individual clients can drop out or be added, and the worst case
scenario is that the specific files they were working on at the time won't get completed (at which point
the server can just be restarted with the list of unfinished inputs, and the remaining clients will handle them.)

The server is run with a list of files to process:
e.g.
`$ ./server --outdir results foo.txt bar.txt`
or 
`$ ./server --outdir results $(ls input-files)`

Any system that wants to contribute can then run e.g.
`./client --server-ip 192.168.0.1 --cmd ./run.sh`

Clients will request input files from the server, store them in a temporary file, 
run the specified command with the file as its argument (e.g. `./run.sh /tmp/foo1234`),
and then send the contents of stdout and stderr back to the server.
The server will store these in the `outdir`, with names equal to the input file's name, postfixed with .stdout and .stderr.
If a command fails, the client will report this, and the results will instead be stored in `outdir`/failures.

The server will keep a continual tally of how many files are queued, in progress, and done.

