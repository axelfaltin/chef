#
# Author:: Tyler Cloke (tyler@chef.io)
# Copyright:: Copyright (c) 2015 Chef Software, Inc
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/json_compat'
require 'chef/mixin/params_validate'

class Chef
  # Top level class for UserKey and ClientKey common functionality.
  # Should only use the subclasses, never this class directly.
  class Key

    include Chef::Mixin::ParamsValidate

    attr_reader :actor_field_name

    # TODO
    def initialize(actor, actor_field_name)
      # Actor that the key is for, either a client or a user, depending on the subclass.
      @actor = actor

      unless actor_field_name == "user" || actor_field_name == "client"
        raise ArgumentError.new("the second argument to initialize must be either 'user' or 'client'")
      end

      @actor_field_name = actor_field_name

      @name = nil
      @public_key = nil
      @expiration_date = nil
    end

    def actor(arg=nil)
      set_or_return(:actor, arg,
                    :regex => /^[a-z0-9\-_]+$/)
    end

    def name(arg=nil)
      set_or_return(:name, arg,
                    :regex => /^[a-z0-9\-_]+$/)
    end

    def public_key(arg=nil)
      set_or_return(:public_key, arg,
                    :kind_of => String)
    end

    def expiration_date(arg=nil)
      set_or_return(:expiration_date, arg,
                    :regex => /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z|infinity)$/)
    end

    # Sets @key_id to the @public_key's fingerprint (which is the default) if
    # @key_id is nil. Should be called before POST-ing
    def set_default_name_if_missing
      # We will initialize the key_id to the fingerprint of the public_key
      if @name == nil
        # TODO: remove duplicate code from chef-server-ctl's key_ctl_helper
        # TODO: is it safe to assume we aren't dealing with certs here?
        openssl_key_object = OpenSSL::PKey::RSA.new(@public_key)
        data_string = OpenSSL::ASN1::Sequence([
                                                OpenSSL::ASN1::Integer.new(openssl_key_object.public_key.n),
                                                OpenSSL::ASN1::Integer.new(openssl_key_object.public_key.e)
                                              ])
        @name = OpenSSL::Digest::SHA1.hexdigest(data_string.to_der).scan(/../).join(':')
      end
    end

    # Following pattern of general leniency in chef-client objects.
    # Allow definition of imporper objects. In reality, calling to_hash on
    # an object that doesn't have any of these fields doesn't make sense.
    # You need all of these fields (especially public_key) to define a key object.
    # However, everywhere in the object code, we allow invalid objects to be defined.
    #
    # Following that pattern here, and validating at the points where POSTs and PUTs are
    # made.
    def to_hash
      result = {
        @actor_field_name => @actor,
      }
      result["name"] = @name if @name
      result["public_key"] = @public_key if @public_key
      result["expiration_date"] = @expiration_date if @expiration_date
      result
    end

    def to_json(*a)
      Chef::JSONCompat.to_json(to_hash, *a)
    end

    # Class methods
    def self.from_hash(key_hash)
      if key_hash.has_key?("user")
        key = Chef::Key.new(key_hash["user"], "user")
      else
        key = Chef::Key.new(key_hash["client"], "client")
      end
      key.name key_hash['name'] if key_hash.key?('name')
      key.public_key key_hash['public_key'] if key_hash.key?('public_key')
      key.expiration_date key_hash['expiration_date'] if key_hash.key?('expiration_date')
    end

    def self.from_json(json)
      Chef::Key.from_hash(Chef::JSONCompat.from_json(json))
    end

    class <<self
      alias_method :json_create, :from_json
    end

  end
end
