### 1 Billion Row Challenge in Zig

This is an implementation of the [1BRC][1brc] in Zig, in order to practice
programming in Zig.

[1brc]: https://github.com/gunnarmorling/1brc

It uses Zig version `0.15.2`


### Results

Using tempfs and reading sequentially

```
1584.67s user 5.15s system 99% cpu 26:31.83 total
```

Reading from spinning disk and using multiple threads

```
469.31s user 2956.70s system 931% cpu 6:07.63 total
```
