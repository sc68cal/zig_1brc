# 1 Billion Row Challenge in Zig

This is an implementation of the [1BRC][1brc] in Zig, in order to practice
programming in Zig.

[1brc]: https://github.com/gunnarmorling/1brc

It uses Zig version `0.15.2`

## Design Notes

### File chunking strategy

It's a relatively naive but I take the file size and divide it by the number of
processing threads, which gives me a `chunk_size`. I allocate a buffer for each
processing thread of size `chunk_size` and then fill the buffer by calling
`File.read`. Because the data is line oriented, I look within the buffer
to find the last newline and then any remaining data will be put into the next
buffer. I then advance the file position after the newline, and then read
`chunk_size` within the file and repeat the process. The only special case is
the last processing thread, where I read to the end of the file.

### Memory allocation strategy

For convenience, I used the Arena Allocator since this CLI program reads from
disk, calculates the values, prints them, then exits. There's no real reason
to deal with freeing memory since the largest allocations are reading the input
file and processing it. An optimization _could_ be written where as soon as a
thread has completed processing the memory containing the data chunk could be
freed, but since the chunks are all of similar size it's likely that all the
threads will complete around the same time. We also have to `wait()` on all the
threads to complete before we print, and then exit so there's not much reason to
optimize that part.


### Multithreading considerations

The main issue with multithreading was implementing a wrapper around the
standard StringHashMap so that multiple threads could mutate the hash map. For
now, a simple mutex is used, but one optimization that could be investigated is
allowing concurrent reads and only using a lock for writing to the map.

## Results

Using tempfs and reading sequentially. This design uses very little memory but 
is slow.

```
1584.67s user 5.15s system 99% cpu 26:31.83 total
```

Reading from spinning disk and using multiple threads.

```
469.31s user 2956.70s system 931% cpu 6:07.63 total
```
