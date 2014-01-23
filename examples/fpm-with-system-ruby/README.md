# About

 - build and install dependency on a ruby1.9 of some kind
 - does not need root to package
 - has its own GEM_DIR to keep its dependencies isolated
 - installation does not install any gems in to your ruby environment
 - installs in to standard locations /usr/{bin,lib}/fpm
 - doesn't depend on having fpm installed for packaging to work

# Dependencies

 - build-essential (perhaps more, but basically the standard packages you need
   for deb packaging)
 - ruby1.9.3 (can be changed)

# Usage

 - $ cd examples/fpm-with-system-ruby
 - $ make package