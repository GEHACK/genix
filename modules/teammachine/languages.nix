{ config, pkgs, ... }: {
    environment.systemPackages = with pkgs; [ 
        jdk21_headless
        pypy3
        libgcc #for c 
        kotlin
    ];
    # Here (or in homemanager) we want to add the following command
    # mygcc
    # mygpp
    # mypython
    # myjavac
    # mykotlinc
}