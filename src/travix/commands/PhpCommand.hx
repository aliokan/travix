package travix.commands;

import tink.cli.Rest;
import Sys.*;

class PhpCommand extends Command {

  var isPHP7Required:Bool;
  var isPHPInstallationRequired:Bool;

  public function new(isPHP7Required) {
    super();
    this.isPHP7Required = isPHP7Required;
  }

  public function install() {

    var haxeMajorVersion = Std.parseInt(run("haxe", ["-version"]).split(".")[0]);
    if(haxeMajorVersion > 3)
        isPHP7Required = true;

    var phpCmd:String = getPhpCommand();
    var phpPackage:String = getPhpPackage();
    var phpVersionPattern:EReg = new EReg(isPHP7Required ? "PHP 7\\.*" : "PHP 5\\.*", "");

    foldOutput("php-install", function() {
      switch(tryToRun(phpCmd, ['--version'])) {
        case Success(out): isPHPInstallationRequired = !phpVersionPattern.match(out);
        case Failure(_):   isPHPInstallationRequired = true;
      }
      if (isPHPInstallationRequired) {
        switch Sys.systemName() {
          case "Linux":
              installPackage('software-properties-common');  // ensure 'add-apt-repository' command is present
              exec('sudo', ['add-apt-repository', '-y', 'ppa:ondrej/php']);
              exec('sudo', ['apt-get', 'update']);
              installPackages([
                phpPackage + "-cli",
                phpPackage + "-mbstring",
                phpPackage + "-mcrypt",
                phpPackage + "-xml"
              ], [ "--allow-unauthenticated" ]);
          case 'Mac':
              exec('brew', ['tap', 'ezzatron/brew-php']); // https://github.com/ezzatron/brew-php
              exec('brew', ['install', 'brew-php']);
              exec('brew', ['php', 'install', phpPackage]);
              exec('brew', ['php', 'link', phpPackage]);
              
          case 'Windows':
              exec('cinst', ['php', '--version', phpPackage]);
            
          case v:
            println('[ERROR] Don\'t know how to install PHP on $v');
            exit(1);
        }
      }

      // print the effective PHP version
      exec(phpCmd, ['--version']);
    });
  }

  public function buildAndRun(rest:Rest<String>) {
    var phpCmd = getPhpCommand();
    
    build(isPHP7Required ? 'php7' : 'php', (isPHP7Required ? ['-php', 'bin/php', '-D', 'php7'] : ['-php', 'bin/php']).concat(rest), function () {
      exec(phpCmd, ['-d', 'xdebug.max_nesting_level=9999', 'bin/php/index.php']);
    });
  }
  
  public function uninstall() {
    if(!isPHPInstallationRequired)
      return;

    var phpPackage = getPhpPackage();
    // removing PHP to be able to run another PhpCommand that may need another PHP version
    foldOutput('php-uninstall', function() {
      switch Sys.systemName() {
        case 'Linux': exec('sudo', ['apt-get', '-q', '-y', 'remove', phpPackage]);
        case 'Mac':  exec('brew', ['remove', phpPackage]);
        case 'Windows':  exec('choco', ['uninstall', 'php']);
      }
    });
  }
  
  function getPhpCommand() {
    return switch Sys.systemName() {
      case "Linux": isPHP7Required ? "php7.1" : "php5.6";
      case _: 'php';
    }
  }
  
  function getPhpPackage() {
    return switch Sys.systemName() {
      case "Linux": isPHP7Required ? "php7.1" : "php5.6";
      case 'Mac': isPHP7Required ? "php71" : "php56";
      case 'Windows': isPHP7Required ? '7.2.11' : '5.6.7';
      case v: Travix.die('[ERROR] Don\'t know how to install PHP on $v');
    }
  }
}
