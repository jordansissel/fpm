Usage:

    make package

Should make the package. Try installing:

    sudo dpkg -i jruby-1.6.0.RC2-1.all.deb

Now try it:

    % /opt/jruby/bin/jirb
    >> require "java"
    => true
    >> java.lang.System.out.println("Hello")
    Hello
    => nil

