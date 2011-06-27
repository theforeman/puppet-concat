#
# Copyright (C) 2011 Onyx Point, Inc. <http://onyxpoint.com/>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
Puppet::Type.type(:concat_fragment).provide :concat_fragment do
  require 'fileutils'

  desc "concat_fragment provider"

  def create
    begin
      group = @resource[:name].split('+').first
      fragment = @resource[:name].split('+')[1..-1].join('+')

      if File.file?("/var/lib/puppet/concat/fragments/#{group}/.~concat_fragments") then
        debug "Purging /var/lib/puppet/concat/fragments/#{group}!"
        FileUtils.rm_rf("/var/lib/puppet/concat/fragments/#{group}")
      end

      FileUtils.mkdir_p("/var/lib/puppet/concat/fragments/#{group}")
      f = File.new("/var/lib/puppet/concat/fragments/#{group}/#{fragment}", "w")
      f.puts @resource[:content]
      f.close
    rescue Exception => e
      fail Puppet::Error, e
    end
  end
end
