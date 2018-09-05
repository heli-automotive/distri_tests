    Distributed tests for Fuego

    As what I said at the ALS meeting(June 2018, Tokyo), in a sense,
    Fuego is similar to Yocto, because both of them know:
    - where is the sourcecode(tarball or giturl)
    - how to build
    - what artifacts should be added/deployed to the final distro/targets

    Now, I think we can develop those tests(Functinal/Benchmark) outside upstream
    Fuego repo(bitbucket), like what Yocto does.

    About development:
    Those Functional/Benchmark tests can be developed distributed, like the meta-xxx
    repo in Yocto. 
    Fuego maintainers can focus on the core framework that they're skilled in.

    About the using way for testers/developers:
    Testers/developers can pull those tests they want from different upstream repo
    when they're using Fuego.
    It's similar to the "tests market" in Fuego(Tim's) mid/long term plan.

    (This is just my own tentative plan above)

