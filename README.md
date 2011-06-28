Puppet Concat Module
====================

This is a module that provides a native type for performing multi-part file
concatenation, generally referred to by the [Puppet Labs](http://www.puppetlabs.com) team as the File
Fragment Pattern.

The concept is based on ideas that R.I. Pienaar describes on his [Building
files from fragments in Puppet](http://www.devco.net/archives/2010/02/19/building_files_from_fragments_with_puppet.php) page.

Installation
------------

The recommended way to install this package is either through the Puppet module
manager or via RPM. A spec file has been included that can be used to create an
RPM if required.

This module is known to be compatible with Puppet 2.6.

Basic Usage
-----------

This module has been designed to be quite flexible but follows the basic
pattern of specifying file fragments and subsequently building a target file. 

See the comments in the code for the definition of all options.

    concat_build { "identifier":
      order => ['*.tmp'],
      target => '/tmp/test'
    }

    concat_fragment { "identifier+01.tmp":
      content => "Some random stuff"
    }

    concat_fragment { "identifier+02.tmp":
      content => "Some other random stuff"
    }

Notes
-----

Concat fragments are stored under /var/lib/puppet/concat/fragments.

TODO
----

* Don't hardcode /var/lib/puppet. Instead use the value of $vardir.

Copyright
---------

Copyright (C) 2011 Onyx Point, Inc. <http://onyxpoint.com/>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
