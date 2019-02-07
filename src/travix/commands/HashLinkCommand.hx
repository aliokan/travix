package travix.commands;

import tink.cli.Rest;

using sys.FileSystem;
using StringTools;

class HashLinkCommand extends Command {

  var hlCommand = "hl";
  
  public function install() {
    if(!Travix.isTravis || !supported())
      return;

    exec('git', 'clone', ['https://github.com/HaxeFoundation/hashlink.git', 'hashlink']);
    exec('cd', ['hashlink']);

    if(Travix.isMac) {
      exec('brew', ['bundle']);
    } 
    
    if(Travix.isLinux) {
      installPackages([
              "libpng-dev",
              "libturbojpeg-dev",
              "libvorbis-dev",
              "libopenal-dev",
              "libsdl2-dev",
              "libmbedtls-dev",
              "libuv1-dev"
            ]);
    }

    exec('make');
    exec('make', 'install');

    exec('cd', ['..']);
  }

  public function buildAndRun(rest:Rest<String>) {
    if(!supported()) return;
    build('hl', ['-hl', 'bin/hl/tests.hl'].concat(rest), function () {
      exec(hlCommand, ['bin/hl/tests.hl']);
    });
  }
  
  function getHaxeVersion() {
    var proc = new sys.io.Process('haxe', ['-version']);
    var stdout = proc.stdout.readAll().toString().replace('\n', '');
    var stderr = proc.stderr.readAll().toString().replace('\n', '');
    
    return switch stdout.split('+')[0].trim() + stderr.split('+')[0].trim() {
      case '4.0.0 (git build master @ 2344f23)': '4.0.0-preview.1';
      case '4.0.0 (git build development @ a018cbd)': '4.0.0-preview.2';
      case v: v;
    }
  }
  
  function supported() {
    var haxeVersion = getHaxeVersion();
    var supported = false;
    if(Travix.isMac) {
      switch haxeVersion {
        case '4.0.0-preview.1' | '4.0.0-preview.2': supported = true;
        case _:
      } 
    }
    if(Travix.isLinux) {
      switch haxeVersion {
        case '4.0.0-preview.4': supported = true;
        case _:
      }
    }
    
    if(!supported) travix.Logger.println('travix hl is not supported on Haxe $haxeVersion, skipping...');
    return supported;
  }
}
