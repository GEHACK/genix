# C and C++ flags of mygcc and mygpp. The runtimes ISO compiles the jury's submissions
# with these too, so its timings hold for what teams build; change them only here.
{
  c = "-std=gnu17 -x c -Wall -O2 -static -pipe";
  cpp = "-std=gnu++20 -x c++ -Wall -O2 -static -pipe";
}
