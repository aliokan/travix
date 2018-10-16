package travix.commands;

import tink.cli.Rest;

import Sys.*;

class LuaCommand extends Command {
  
  public function install() {
    if(command('eval', ['which luarocks >/dev/null']) != 0) {
      foldOutput('lua-install', function() {
        if(Travix.isLinux) {
          if(command('eval', ['bash -c "[ \\"`lsb_release -s -c`\\" == \\"precise\\" ]"']) == 0) {
            // Required repo for precise to build cmake
            exec('eval', ['sudo add-apt-repository -y ppa:george-edison55/precise-backports']);
          }

          installPackages([
            "cmake",
            "libpcre3",
            "libpcre3-dev",
            "lua5.2",
            "make",
            "unzip"
          ]);

          var luaRocksVersion = '2.4.3';

          // Add source files so luarocks can be compiled
          exec('sudo', ['mkdir', '-p', '/usr/include/lua/5.2']);
          exec('wget', ['-q', 'http://www.lua.org/ftp/lua-5.2.0.tar.gz']);
          exec('tar', ['xf', 'lua-5.2.0.tar.gz']);
          exec('eval', ['sudo cp lua-5.2.0/src/* /usr/include/lua/5.2']);
          exec('rm', ['-rf', 'lua-5.2.0']);
          exec('rm', ['-f', 'lua-5.2.0.tar.gz']);

          // Compile luarocks
          exec('wget', ['-q', 'http://luarocks.org/releases/luarocks-$luaRocksVersion.tar.gz']);
          exec('tar', ['zxpf', 'luarocks-$luaRocksVersion.tar.gz']);

          withCwd('luarocks-$luaRocksVersion', function() {
            exec('./configure');
            exec('eval', ['make build >/dev/null']);
            exec('eval', ['sudo make install >/dev/null']);
          });

          exec('rm', ['-f', 'luarocks-$luaRocksVersion.tar.gz']);
          exec('rm', ['-rf', 'luarocks-$luaRocksVersion']);
        } 
        
        if(Travix.isMac || Travix.isWindows) {
          installPackage('lua');
          installPackage('luarocks');
        }

        // Install lua libraries
        // Based on https://github.com/HaxeFoundation/haxe/blob/3a6d024019aad28ab138fbb88cade34ff2e5bf19/tests/RunCi.hx#L473
        exec('sudo', 'luarocks install lrexlib-pcre 2.9.0-1'.split(' '));
        exec('sudo', 'luarocks install luv 1.9.1-1'.split(' '));
        exec('sudo', 'luarocks install luasocket 3.0rc1-2'.split(' '));
        exec('sudo', 'luarocks install environ 0.1.0-1'.split(' '));
        exec('sudo', 'luarocks install luautf8 0.1.1-1'.split(' '));
      });
    }

    // print the effective versions
    exec("luarocks", ['--version']);
    exec("lua", ['-v']);
  }

  public function buildAndRun(rest:Rest<String>) {
    build('lua', ['-lua', 'bin/lua/tests.lua'].concat(rest), function () {
      exec('lua', ['bin/lua/tests.lua']);
    });
  }
}
