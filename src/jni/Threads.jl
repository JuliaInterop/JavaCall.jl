"""
    JavaCall.JNI.Threads is a standin module for Base.Threads

    On Windows, it disables multithreading for JavaCall since JavaCall becomes
    unstable in Windows.

    On other operating systems, it just uses Base.Threads.
"""
module Threads
    @static if Sys.iswindows()
        threadid() = 1
        nthreads() = 1
        resize_nthreads!(x) = x
        macro threads(expr)
            esc(expr)
        end
    else
        import Base.Threads: resize_nthreads!, @threads, threadid, nthreads
    end
end
