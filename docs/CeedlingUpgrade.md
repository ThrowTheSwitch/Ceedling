# Upgrading Ceedling

You'd like to stay in sync with the latest Ceedling... and who wouldn't? Depending on 
how you've made use of Ceedling, that may vary slightly. No matter what, though, our first
step is to update Ceedling itself.

## Step 1: Update Ceedling Itself

```
gem update ceedling
```

That should do it... unless you don't have a valid connection to the internet. In that case,
you might have to download the gem from rubygems.org and then install it manually:

```
gem update ceedling --local=ceedling-filename.zip
```

## Step 2: Udpate Projects Using Ceedling

When you set up your project(s), it was either configured to use the gem directly, or it was
configured to install itself locally (often into a vendor directory).

For projects that are of the first type, congratulations, you're finished. The project will
automatically use the new ceedling. There MAY be things that need to be tweaked if features have
moved significantly. (And we apologize if that's your situation... as we get to version 1, we're
going to have a stronger focus on backwards compatibility). If your project isn't working perfectly, 
skip down to Step 3.

If the project was installed to have a copy of ceedling locally, you have a choice. You may 
choose to continue to run THIS project on the old version of Ceedling. Often this is the
preferred method for legacy projects which only get occasional focus. Why go through the effort 
of updating for new tools if it's serving its purpose and you're unlikely to actually use the new
features?

The other choice, of course, is to update it. To do so, we open a command prompt and address ceedling 
from *outside* the project. For example, let's say we have the following structure:

 - projects
    - myproject
        - project.yml
        - src
        - tgt
        - vendor

In this case, we'd want to be in the `projects` directory. At that point, we can ask Ceedling to
update our project.

```
ceedling upgrade myproject
```

Ceedling will automatically look for your project yaml file and do its best to determine what needs
to be updated. If installed locally, this will mean copying the latest copy of Unity, CMock, and
Ceedling. It will also involve copying documentation, if you had that installed.

## Step 3: Solving Problems

We wish every project would update seamlessly... unfortunately there is a lot of customization that
goes into each project, and Ceedling often isn't aware of all of these. To make matter worse, Ceedling
has been in pre-release for awhile, meaning it occasionally has significant changes that may break
current installations. We've tried to capture the common ones here:

### rakefile

Ceedling is built in a utility called Rake. In the past, rake was the method that the user actually
interacted with Ceedling. That's no longer the case. Using a modern version of Ceedling means that
you issue commands like `ceedling test:all` instead of `rake test:all`. If you have a continuous 
integration server or other calling service, it may need to be updated to comply.

Similarly, older versions of Ceedling actually placed a rakefile in the project directory, allowing 
the project to customize its own flow. For the most part this went unused and better ways were later
introduced. At this point, the `rakefile` is more trouble than its worth and often should just be 
removed. 

### plugins

If you have custom plugins installed to your project, the plugin architecture has gone through some 
revisions and it may or may not be compatible at this time. Again, this is a problem which should
not exist soon.


