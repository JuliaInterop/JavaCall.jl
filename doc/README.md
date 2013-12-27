#Documentation for JavaCall.jl

This directory contains the documentation for the JavaCall.jl package. 

Documentation is maintained in markdown files in this directory. 
In addition, this directory is the source of a jekyll site that builds the
project homepage at http://aviks.github.com/JavaCall.jl/ . That website can 
be built and pushed to github pages from here. 

To build the jekyll site, the following dependencies are required.  

```bash
sudo gem install jekyll
sudo gem install redcarpet
#Pygments 1.6+ (unreleased) is required
sudo easy_install http://bitbucket.org/birkenfeld/pygments-main/get/tip.zip#egg=Pygments-dev

julia push-gh-pages.jl
```
