# Ceedling Installation & Set Up

**How Exactly Do I Get Started?**

You have two good options for installing and running Ceedling:

1. The Ceedling Ruby Gem
1. Prepackaged _MadScienceLab_ Docker images

The simplest way to get started with a local installation is to install 
Ceedling as a Ruby gem. Gems are simply prepackaged Ruby-based software.
Other options exist, but the Ceedling Gem is the best option for a local
installation. However, you will also need a compiler toolchain (e.g. GNU
Compiler Collection) plus any supporting tools used by any plugins you
enabled.

If you are familiar with the virtualization technology Docker, our premade
Docker images will get you started with Ceedling and all the accompanying
tools lickety split. Install Docker, pull down one of the _MadScienceLab_
images and go.

## Installation as a [Ruby Gem][ruby-gem]

1. [Download and install Ruby][ruby-install]. Ruby 3 is required.

1. Use Ruby's command line gem package manager to install Ceedling from
   the [RubyGems repository][rubygems-repo]: `gem install ceedling`.
    * Unity and CMock come along with Ceedling at no extra charge.
    * Installing from the RubyGems repo will also install Ceedling's 
     dependencies.
1. Execute Ceedling at the command line to export an example project
   or create an empty Ceedling project in your filesystem (executing
   `ceedling help` first is, well, helpful).

[ruby-gem]: http://docs.rubygems.org/read/chapter/1
[ruby-install]: http://www.ruby-lang.org/en/downloads/
[rubygems-repo]: http://rubygems.org

### Gem install notes

Steps 1–2 above are a one-time affair for your local environment. 
When steps 1-2 are completed once, only step 3 is needed for each new 
code projects.

If you are working with prerelease versions of Ceedling or some other 
off-the-beaten-path installation scenario, you may want to directly 
install the Ceedling .gem file attached to any of the Github releases.
No problem.

The steps are similar to the preceding with two changes:

1. `gem install --local <ceedling .gem filepath>`
1. Any missing dependencies must be manually installed before 
installation of the local Ceedling gem will succeed. A local 
installation attempt will complain about any missing dependencies. 
Simply `gem install` them by name.

## _MadScienceLab_ Docker Images

As an alternative to local installation, fully packaged Docker images containing Ruby, Ceedling, the GCC toolchain, and more are also available. [Docker][docker-overview] is a virtualization technology that provides self-contained software bundles that are a portable, well-managed alternative to local installation of tools like Ceedling.

Four Docker image variants containing Ceedling and supporting tools exist. These four images are available for both Intel and ARM host platforms (Docker does the right thing based on your host environment). The latter includes ARM Linux and Apple's M-series macOS devices.

1. **_[MadScienceLab][docker-image-base]_**. This image contains Ruby, Ceedling, CMock, Unity, CException, the GNU Compiler Collection (gcc), and a handful of essential C libraries and command line utilities.
1. **_[MadScienceLab Plugins][docker-image-plugins]_**. This image contains all of the above plus the command line tools that Ceedling's built-in plugins rely on. Naturally, it is quite a bit larger than option (1) because of the additional tools and dependencies.
1. **_[MadScienceLab ARM][docker-image-arm]_**. This image mirrors (1) with the compiler toolchain replaced with the GNU `arm-none-eabi` variant. 
1. **_[MadScienceLab ARM + Plugins][docker-image-arm-plugins]_**. This image is (3) with the addition of all the complementary plugin tooling just like (2) provides.

See the Docker Hub pages linked above for more documentation on these images.

Just to be clear here, most users of the _MadScienceLab_ Docker images will probably care about the ability to run unit tests on your own host. If you are one of those users, no matter what host platform you are on — Intel or ARM — you'll want to go with (1) or (2) above. The tools within the image will automatically do the right thing within your environment. Options (3) and (4) are most useful for specialized cross-compilation scenarios.

### Usage basics

To use a _MadScienceLab_ image from your local terminal:

1. [Install Docker][docker-install]
1. Determine:
    1. The local path of your Ceedling project
    1. The variant and revision of the Docker image you'll be using
1. Run the container with:
    1. The Docker `run` command and `-it --rm` command line options
    1. A Docker volume mapping from the root of your project to the default project path inside the container (_/home/dev/project_)

See the command line examples in the following two sections.

Note that all of these somewhat lengthy command lines lend themselves well to being wrapped up in simple helper scripts specific to your project and directory structure.

### Run as an interactive terminal

When the container launches as shown below, it will drop you into a Z-shell command line that has access to all the tools and utilities available within the container. In this usage, the Docker container becomes just another terminal, including ending its execution with `exit`.

```shell
 > docker run -it --rm -v /my/local/project/path:/home/dev/project throwtheswitch/madsciencelab-plugins:1.0.0
```

Once the _MadScienceLab_ container's command line is available, to run Ceedling, execute it just as you would after installing Ceedling locally:

```shell
 ~/project > ceedling help
```

```shell
 ~/project > ceedling new ...
```

```shell
 ~/project > ceedling test:all
```

### Run as a command line utility

Alternatively, you can run Ceedling through the _MadScienceLab_ Docker container directly from the command line as a command line utility. The general pattern is immediately below.

```shell
 > docker run --rm -v /my/local/project/path:/home/dev/project throwtheswitch/madsciencelab-plugins:1.0.0 <Ceedling command line>
```

As a specific example, to run all tests in a suite, the command line would be this:

```shell
 > docker run --rm -v /my/local/project/path:/home/dev/project throwtheswitch/madsciencelab-plugins:1.0.0 ceedling test:all
```

In this usage, the container starts, executes Ceedling, and then ends.

[docker-overview]: https://www.ibm.com/topics/docker
[docker-install]: https://www.docker.com/products/docker-desktop/

[docker-image-base]: https://hub.docker.com/repository/docker/throwtheswitch/madsciencelab
[docker-image-plugins]: https://hub.docker.com/repository/docker/throwtheswitch/madsciencelab-plugins
[docker-image-arm]: https://hub.docker.com/repository/docker/throwtheswitch/madsciencelab-arm-none-eabi
[docker-image-arm-plugins]: https://hub.docker.com/repository/docker/throwtheswitch/madsciencelab-arm-none-eabi-plugins

## Getting Started after installation

1. Certain advanced features of Ceedling rely on `gcc` and `cpp` as
   preprocessing tools. In most Linux systems, these tools are already available.
   For Windows environments, we recommend the 
   [MinGW project](http://www.mingw.org/) (Minimalist GNU for Windows). This 
   represents an optional, additional setup / installation step to complement 
   the list above. Upon installing MinGW ensure your system path is updated or 
   set `:environment` ↳ `:path` in your project configuration (see `:environment`
   section).

1. Once Ceedling is installed, you'll want to start to integrate it with new
   and old projects alike. If you wanted to start to work on a new project
   named `foo`, Ceedling can create the skeleton of the project using `ceedling
   new foo <destination>`. Likewise if you already have a project named `bar` 
   and you want to "inject" Ceedling into it, you would run `ceedling new bar 
   <destination>`, and Ceedling will create any files and directories it needs.

1. Now that you have Ceedling integrated with a project, you can start using it.
   A good starting point is to enable the [plugin](../plugins/index.md) 
   `module_generator` in your project configuration file and create a source +
   test code module to get accustomed to Ceedling by issuing the command 
   `ceedling 'module:create[name]'`.

<br/><br/>
