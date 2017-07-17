#Documentation for JavaCall.jl

This directory contains the documentation for the JavaCall.jl package. 

Documentation is maintained in markdown files in this directory. 
In addition, this directory is the source of a jekyll site that builds the
project homepage at http://juliainterop.github.io/JavaCall.jl/. That website can 
be built and pushed to github pages from here. 

To build the jekyll site, the following dependencies are required.  

```bash
sudo gem install jekyll
sudo gem install redcarpet
sudo pip install pygments

# run locally (will create subdirectory _site)
jekyll build

# publish
julia push-gh-pages.jl
```
