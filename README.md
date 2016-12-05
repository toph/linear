# Quick Run / Interpreted (recommended for simplicify)

    # Requires RVM for Ruby
    $ ./build.sh
    $ ./run.sh linesfile.txt

# Compile to Jar and Run

    # Requires RVM for Ruby
    $ ./build-jar.sh
    $ ./run-jar.sh linesfile.txt

# How does your system work?

I pre-generate an index file. The index file contains a list of offsets for the start of each line in the text file.

The offsets are encoded in the index as fixed size integers. I used uint64s to make sure I could encode offsets for any file I'm likely to encounter.

You could save space by using uint32s for smaller files. Or you could cover both cases with a variable encoding scheme where the first byte of the file specified the length of the offsets... but simplicity is good.

To find line N's position in the text file, go to position `N * size` in the index (e.g. `N * 8`), read `size` bytes (8 bytes) into an unsigned integer M (the bytes are specified to be in little endian order so as to be portable). Then read from the text file starting at offset M until a newline or eof is encountered.

Always good to mention in these writeups: the code described above is O(1) itself. Getting to the right block for the data in the filesystem might be O(log n) with regards to file size (i.e. trees). But if you really cared you might be able to use raw disk partitions to avoid that. Anyway, from a 10,000ft view: the code should behave very well.

The system is built using JRuby and Puma and therefore is threaded. Each thread has its own file handles to the source file and the index file in thread local storage.

# How will your system perform with a 1 GB file? a 10 GB file? a 100 GB file?

Since the system does not require either the source file or the index file to fit in memory, and because positions are encoded as uint64s in the index, it should be able to handle all three of those sizes without crashing. A file bigger than 2**64 would be problematic, but that's REALLY big.

However, building the index will certainly take longer with a larger file. Pre-building is a very good idea and distributing the indices to the servers alongside the text file makes sense.

Tangent: My new favorite trick for distributing immutable data with occasional updates is to use AWS ElasticFileSystem (it's basically extra reliable NFS) to distribute the immutable files with a timestamp in the name. You can then have a thread in the server whose job it is to watch for newer versions, copy them to local storage, and gracefully restart the http handler threads automatically.

The filesystem cache will help optimize our performance in cases where the data set fits in memory (actually, also in cases where it doesn't fit too).

However, if we knew files were guaranteed to fit in memory, we could make additional improvements. Some languages make it easy to mmap data into memory and then access the native values directly (C, C++, Rust, etc).

# How will your system perform with 100 users? 10000 users? 1000000 users?

User count alone doesn't tell you much about expected system load. It's probably simpler to reason about peak requests per second. If this information isn't available, it can probably be inferred from historical user and load information.

Benchmarking a 1GB file on an EC2 C4.xlarge instance using Vegata I'm able to sustain 5300 req/s. On an EC2 C4.2xlarge, I'm able to sustain a 7400 req/s. Depending on the req/s per user, this means a single machine might well be able to handle the full load.

And, luckily, since things could get hairy on the way to 1,000,000 users, this solution can effectively be infinitely horizontally scaled because the data is immutable. I'd suggest an ELB and an EC2 auto scaling group (plus possibly the EFS distribution trick mentioned earlier).

The C4.xlarge costs $0.199/hour to run.  At 5300 req/s with 60 secs per min and 60 mins per hour we get 5300 * 60 * 60 = 19080000 req/hour. That gives us a cost of $0.00000001043/req.

Unfortunately, I appear to be hitting a bottle neck in JRuby/Puma that's keeping me from perfect scaling. The CPUs on the server instances are not fully saturated and, worse, the C4.2xlarge wasn't twice as fast as the C4.xlarge. Given a bottleneck like this, using smaller EC2 machines is likely to bring us closer to the sweet spot and increase our efficiency.

In case you're curious, I did want to check to make sure I wasn't just hitting a limit of my benchmarking tool. So, I brought up a second client machine and split the load. Same limits. At this point, I'm pretty sure its server side.

I've also verified the rates produced with Vegeta are similar to rates produced using other benchmarking tools like AB, wrk, and hey. I chose Vegeta because it seems better at maintaining stable target hit rates.

Also worth noting, the benchmarks make sure to sample across the lines file to try to simulate "realistic" load. I've generated the request inputs as follows:

`ruby -e 'open("reqs.txt", "w") { |f| 22659000.times.map { |i| "GET http://172.31.62.33:4567/line/#{i}" }.shuffle[0...100_000].each { |r| f.puts(r) } }'`

And... because I couldn't help it, I did some benchmarking against MRI. I wanted to see what, if any, benefit I got from using JRuby.

Interestingly, Puma on MRI (just using Ruby's standard GIL restricted threads) did 3000 req/s. That's much closer to JRuby than I anticipated. Picking a smaller machine size (to avoid underutilizing the CPUs) and scaling wider could make this a very effective strategy if you wanted to stick with MRI.

I also tried Unicorn with both low and high (150) process counts. I was unable to break 1300 req/s.

Finally, I tried my personal favorite for MRI: a Passenger Phusion setup. With Passenger, I could squeeze out 4900 req/s which is awfully close to JRuby/Puma. However, the Passenger setup fully maxed out the CPU and has a more complicated deployment config requiring Nginx, Passenger, and a Ruby environment configured to match. It requires quite a few more moving parts than a single JRuby built jar that runs via `java`.

Benchmarking always leaves me nervous--small changes or misconfigurations can easily lead to incorrect conclusions. Nevertheless, I wanted to share my results.

# What documentation, websites, papers, etc did you consult in doing this assignment?

Just Ruby docs for various gems.

I looked at some old code I had written to spawn Puma manually instead of via `puma` or `rackup` (so you can paramaterize the App instantiation with the command line args) and some old notes I took about using Warbler to build jars of JRuby projects.

# What third-party libraries or other tools does the system use? How did you choose each library or framework you used?

Well, JRuby is a fairly outside of the box solution. It gets a bad reputation because of the issues one sees when running something designed for MRI on it. Sometimes a necessary library just isn't compatible. But if you're targeting it from the beginning (effectively treat it as its own language), it's not bad at all.

Anyway, JRuby is an interesting language for building microservices in because of the faster performance and non-GIL limited threading. While the concurrency primitives in Ruby aren't nearly as good as in Java or Scala, there is a growing set of useful concurrency libraries, plus the Java classes if necessary.

Additionally, using Warbler to build a `.jar` file that contains a builtin web server like Puma can simplify deployment and server config. And you get free AOT compilation for the JRuby code!

In general, I stick with MRI for most projects--it's often not worth the extra effort to use JRuby. But there are certain classes of projects that it can be a good fit for. Assuming you'd prefer to stick with Ruby instead of Scala or Java (or Go ;-).

I used Puma, Rack, and Sinatra for the web server. Rack's basically everywhere in Ruby if you're doing HTTP. Sinatra is the default if you want a lighter framework than Rails. I selected Puma to compliment JRuby and to try to get the best performance possible for this service.

For testing I used minitest in test unit mode, instead of rspec--mostly just because I'm slightly more familiar with test unit, though I've used rspec as well.

I have CircleCI configured for continuous integration and I used Rubocop to keep my code honest. =)

[Continuous Integration setup here...](https://circleci.com/gh/toph/linear)

# How long did you spend on this exercise? If you had unlimited more time to spend on this, how would you spend it and how would you prioritize each item?

It was hard to carve out uninterrupted time to work on it, so I worked in several bursts. I think I spent around 6 core hours. That includes fighting with Puma and Sinatra for a while because I forgot to call `super` in my Sinatra `App#initialize` override. It also includes all the time I spent doing this writeup.

Beyond that I spent a couple additional hours on a plugin system that supported multiple backends (instead of just hardcoding `Index`) because I thought it might make for a good conversation during code review. I coded the following plugins: `Index`, `InMemory`, `FilePerLine`, `Sqlite`, and `RewindAndScan`. But I ultimately removed them from the submitted version because the plugin system reduced clarity and `Index` was still my preferred implemenation.

Finally, I spent another two hours doing benchmarking on EC2.

If I had more time, I would probably spend a bit digging into the JRuby/Puma bottleneck and/or finding the optimal machine size to work around it. Not to mention deployment logic would need to be built if this was going into production. And of course, the whole question of distributing the immutable data.

In general, though, I'm pretty happy with the code as is and wouldn't prioritize any more work on it without a specific need.

# If you were to critique your code, what would you have to say about it?

If I were a reviewer, I might say:

 - Tests could be a little more rigorous.

 - I might also look askance at the the JRuby selection. It's a pretty unusual choice. As a reviewer, I'd want to reassure myself that the choice was more of a conversation piece than some crazy dogma.

# Thoughts on SQL Based Approaches

While a centralized DB like MySQL or PostgreSQL is a bad fit for something like this (adds a bottleneck without any really advantage), there is one SQL based solution that could be a good fit...

Sqlite databases are a really cool way to distribute immutable data. They allow you to keep things like indexes and data in the same file, give filtering capabilities for bulk requests, etc.

Plus, if you open the files using `?immutable=1&cache=shared` you can actually share the Sqlite memory caches across threads.

You can also do things like copying databases into memory with a single command and even serve requests from the disk file while you build in the in memory cache.

Anyway, it seemed like overkill here, but it is an interesting general solution.