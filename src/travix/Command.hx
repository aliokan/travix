package travix;

import Sys.*;
import sys.io.Process;

using StringTools;
using haxe.io.Path;
using sys.FileSystem;
using sys.io.File;

class Command {

  var isFirstPackageInstallation = true;

  public function new() {}

  function enter(what:String, ?def:String)
    switch def {
      case null:
        println('Please specify $what');
        while (true) {
          switch Sys.stdin().readLine().trim() {
            case '':
            case v: return v;
          }
        }
      default:
        println('Please specify $what (default: $def):');
        return switch Sys.stdin().readLine().trim() {
          case '': def;
          case v: v;
        }
    }

  function ask(question:String, yes:Bool) {
    var defaultAnswer = if (yes) "yes" else "no";
    while (true) {
      print('$question? ($defaultAnswer)');
      switch Sys.stdin().readLine().trim().toUpperCase() {
        case '': return yes;
        case 'YES', 'Y': return true;
        case 'NO', 'N': return false;
        default:
      }
    }

    return throw 'unreachable';
  }

  function tryToRun(cmd:String, ?params:Array<String>)
    return try {
      #if (hxnodejs && !macro)
        var ret = js.node.ChildProcess.spawnSync(cmd, params);
        function str(buf:js.node.Buffer)
          return buf.toString();
        if (ret.status == 0)
          Success(str(ret.stderr) + str(ret.stdout));
        else
          Failure(ret.status, str(ret.stderr));
      #else
      var p = new Process(cmd, params);
      switch p.exitCode() {
        case 0:
          Success(switch p.stdout.readAll().toString() {
            case '': p.stderr.readAll().toString(); //some execs print to stderr
            case v: v;
          });
        case v:
          Failure(v, p.stderr.readAll().toString());
      }
      #end
    } catch (e:Dynamic) {
      Failure(404, 'Unknown command $cmd');
    }

  function run(cmd:String, ?params:Array<String>) {
    var a = [cmd];
    if (params != null)
      a = a.concat(params);

    print('> ${a.join(" ")} ...');
    return
      switch tryToRun(cmd, params) {
        case Success(v):
          println(' done');
          v;
        case Failure(code, out):
          println(' failure');
          print(out);
          exit(code);
          throw 'unreachable';
      }
  }

  function libInstalled(lib:String)
    return tryToRun('haxelib', ['path', lib]).match(Success(_));

  function installLib(lib:String, ?version = '') {

    foldOutput('installLib-$lib', function() {
      if (!libInstalled(lib))
      switch version {
        case null | '':
          exec('haxelib', ['install', lib, '--always']);
        default:
          exec('haxelib', ['install', lib, version, '--always']);
        }
    });
  }

  function foldOutput<T>(tag:String, func:Void->T) {
    tag = tag.replace('+', 'plus');
    if(Travix.isTravis) Sys.println('travis_fold:start:$tag.${Travix.counter}');
    var result = func();
    if(Travix.isTravis) Sys.println('travis_fold:end:$tag.${Travix.counter}');
    return result;
  }

  function ensureDir(dir:String) {
    var isDir = dir.extension() == '';

    if (isDir)
      dir = dir.removeTrailingSlashes();

    var parent = dir.directory();
    if (parent.removeTrailingSlashes() == dir) return;
    if (!parent.exists())
      ensureDir(parent);

    if (isDir && !dir.exists())
      dir.createDirectory();
  }

  function build(tag, args:Array<String>, run) {
    args = args.concat(['-lib', 'travix']);
    switch Travix.getInfos() {
      case None: // do nothing
      case Some(info): args = args.concat(['-lib', info.name]);
    }
    if(Travix.TESTS.exists()) args.push(Travix.TESTS);
    
    foldOutput('build-$tag', exec.bind('haxe', args));
    run();
  }

  function isDebugBuild(args:Array<String>):Bool {
    function declaresDebugFlag(file:String):Bool {
      for (line in file.getContent().split('\n').map(function (s:String) return s.split('#')[0].trim())) {
        if (line == '-debug')
          return true;
        if (line.endsWith('.hxml') && declaresDebugFlag(line))
          return true;
      }
      return false;
    }

    for (arg in args) {
      if (arg == '-debug')
        return true;
      if (arg.endsWith('.hxml') && declaresDebugFlag(arg))
        return true;
    }

    if (Travix.TESTS.exists() && declaresDebugFlag(Travix.TESTS))
      return true;

    return false;
  }

  #if (hxnodejs && !macro)
    static inline function command(cmd:String, ?args:Array<String>):Int {
      if (args == null)
        return js.node.ChildProcess.spawnSync(cmd, cast {stdio: "inherit", shell: true }).status;
      else
        return js.node.ChildProcess.spawnSync(cmd, args, cast {stdio: "inherit", shell: true }).status;
    }
  #end

  function exec(cmd, ?args) {
    var a = [cmd];
    if (args != null)
      a = a.concat(args);
    println('> ' + a.join(' '));
    switch command(cmd, args) {
      case 0:
      case v: exit(v);
    }
  }

  function withCwd<T>(dir:String, f:Void->T) {
    var old = getCwd();
    setCwd(dir);
    var ret = f();
    setCwd(old);
    return ret;
  }

  /**
   * Installs software packages using a os-specific pacakge manager. "apt-get" on Linux and "brew" on MacOs.
   *
   * @param additionalArgs additional flags/options to be passed to the package manager
   */
  inline function installPackages(packageNames:Array<String>, ?additionalArgs:Array<String>) {
    for (p in packageNames)
      installPackage(p, additionalArgs);
  }

  /**
   * Installs a software package using a os-specific pacakge manager. "apt-get" on Linux and "brew" on MacOs.
   *
   * @param additionalArgs additional flags/options to be passed to the package manager
   */
  function installPackage(packageName:String, ?additionalArgs:Array<String>) {
    if (additionalArgs == null) additionalArgs = [];
    foldOutput('installPackage-$packageName', function() {
      switch Sys.systemName() {
        case 'Linux':
          if (isFirstPackageInstallation) {
            exec('sudo', ['apt-get', 'update', '-qq']);
            isFirstPackageInstallation = false;
          }
          exec('sudo', ['apt-get', 'install', '--no-install-recommends', '-qq', packageName].concat(additionalArgs));
        case 'Mac':
          if (isFirstPackageInstallation) {
            exec('brew', ['update']); // to prevent "Homebrew must be run under Ruby 2.3!" https://github.com/travis-ci/travis-ci/issues/8552#issuecomment-335321197
            isFirstPackageInstallation = false;
          }
          exec('brew', ['install', packageName].concat(additionalArgs));
        case 'Windows':
          exec('cinst', [packageName].concat(additionalArgs));
          exec('refreshenv');
        case v:
          println('WARN: Don\'t know how to install packages on $v');
      }
    });
  }
}


enum RunResult {
  Success(output:String);
  Failure(code:Int, output:String);
}
