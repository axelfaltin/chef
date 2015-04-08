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

require 'spec_helper'

require 'chef/key'

describe Chef::Key do
  # whether user or client irrelevent to these tests
  let(:key) { Chef::Key.new("original_actor", "user") }
  let(:public_key_string) do
     <<EOS
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvPo+oNPB7uuNkws0fC02
KxSwdyqPLu0fhI1pOweNKAZeEIiEz2PkybathHWy8snSXGNxsITkf3eyvIIKa8OZ
WrlqpI3yv/5DOP8HTMCxnFuMJQtDwMcevlqebX4bCxcByuBpNYDcAHjjfLGSfMjn
E5lZpgYWwnpic4kSjYcL9ORK9nYvlWV9P/kCYmRhIjB4AhtpWRiOfY/TKi3P2LxT
IjSmiN/ihHtlhV/VSnBJ5PzT/lRknlrJ4kACoz7Pq9jv+aAx5ft/xE9yDa2DYs0q
Tfuc9dUYsFjptWYrV6pfEQ+bgo1OGBXORBFcFL+2D7u9JYquKrMgosznHoEkQNLo
0wIDAQAB
-----END PUBLIC KEY-----
EOS
  end

  shared_examples_for "fields with username type validation" do
    context "when invalid input is passed" do
      # It is not feasible to check all invalid characters.  Here are a few
      # that we probably care about.
      it "should raise an ArgumentError" do
        # capital letters
        expect { key.send(field, "Bar") }.to raise_error(ArgumentError)
        # slashes
        expect { key.send(field, "foo/bar") }.to raise_error(ArgumentError)
        # ?
        expect { key.send(field, "foo?") }.to raise_error(ArgumentError)
        # &
        expect { key.send(field, "foo&") }.to raise_error(ArgumentError)
        # spaces
        expect { key.send(field, "foo ") }.to raise_error(ArgumentError)
      end
    end
  end

  shared_examples_for "string fields that are settable" do
    context "when it is set with valid input" do
      it "should set the field" do
        key.send(field, valid_input)
        expect(key.send(field)).to eq(valid_input)
      end

      it "raises an ArgumentError if you feed it anything but a string" do
        expect { key.send(field, Hash.new) }.to raise_error(ArgumentError)
      end
    end
  end

  describe "when a new Chef::Key object is initialized with invalid input" do
    it "should raise an ArgumentError" do
      expect { Chef::Key.new("original_actor", "not_a_user_or_client") }.to raise_error(ArgumentError)
    end
  end

  describe "when a new Chef::Key object is initialized with valid input" do
    it "should be a Chef::Key" do
      expect(key).to be_a_kind_of(Chef::Key)
    end

    it "should properly set the actor" do
      expect(key.actor).to eq("original_actor")
    end
  end

  describe "when actor field is set" do
    it_should_behave_like "string fields that are settable" do
      let(:field) { :actor }
      let(:valid_input) { "new_field_value" }
    end

    it_should_behave_like "fields with username type validation" do
      let(:field) { :actor }
    end
  end

  describe "when the name field is set" do
    it_should_behave_like "string fields that are settable" do
      let(:field) { :actor }
      let(:valid_input) { "new_field_value" }
    end

    it_should_behave_like "fields with username type validation" do
      let(:field) { :name }
    end
  end

  describe "when the public_key field is set" do
    it_should_behave_like "string fields that are settable" do
      let(:field) { :public_key }
      let(:valid_input) { "new_field_value" }
    end
  end

  describe "when the expiration_date field is set" do
    context "when a valid date is passed" do
      it_should_behave_like "string fields that are settable" do
        let(:field) { :public_key }
        let(:valid_input) { "2020-12-24T21:00:00Z" }
      end
    end

    context "when infinity is passed" do
      it_should_behave_like "string fields that are settable" do
        let(:field) { :public_key }
        let(:valid_input) { "infinity" }
      end
    end

    context "when an invalid date is passed" do
      it "should raise an ArgumentError" do
        expect { key.expiration_date "invalid_date" }.to raise_error(ArgumentError)
        # wrong years
        expect { key.expiration_date "20-12-24T21:00:00Z" }.to raise_error(ArgumentError)
      end

      context "when it is a valid UTC date missing a Z" do
        it "should raise an ArgumentError" do
          expect { key.expiration_date "2020-12-24T21:00:00" }.to raise_error(ArgumentError)
        end
      end
    end
  end # when the expiration_date field is set

  describe "when set_default_name_if_missing is called and @public_key is set" do
    before do
      key.public_key public_key_string
    end

    context "when @name is not nil" do
      before do
        key.name "not_nil"
      end

      it "should not change the name field" do
        key.set_default_name_if_missing
        expect(key.name).to eq("not_nil")
      end
    end

    context "when @name is nil" do
      it "should set the name field to the fingerprint of @public_key" do
        key.set_default_name_if_missing
        expect(key.name).to eq("12:3e:33:73:0b:f4:ec:72:dc:f0:4c:51:62:27:08:76:96:24:f4:4a")
      end
    end
  end # when set_default_name_if_missing is called and @public_key is set


  describe "when serializing to JSON" do
    shared_examples_for "common json operations" do
      it "should serializes as a JSON object" do
        expect(json).to match(/^\{.+\}$/)
      end

      it "should include the actor value under the key relative to the actor_field_name passed" do
        expect(json).to include(%Q("#{new_key.actor_field_name}":"original_actor"))
      end

      it "should include the name field when present" do
        new_key.name("monkeypants")
        expect(new_key.to_json).to include(%q{"name":"monkeypants"})
      end

      it "should not include the name if not present" do
        expect(json).to_not include("name")
      end

      it "should include the public_key field when present" do
        new_key.public_key public_key_string
        expect(new_key.to_json).to include(%Q("public_key":"#{public_key_string}"))
      end

      it "should not include the public_key if not present" do
        expect(json).to_not include("public_key")
      end

      it "should include the expiration_date field when present" do
        new_key.expiration_date "2020-12-24T21:00:00Z"
        expect(new_key.to_json).to include(%Q("expiration_date":"2020-12-24T21:00:00Z"))
      end

      it "should not include the expiration_date if not present" do
        expect(json).to_not include("expiration_date")
      end
    end

    context "when key is for a user" do
      it_should_behave_like "common json operations" do
        let(:new_key) { Chef::Key.new("original_actor", "user") }
        let(:json) do
          new_key.to_json
        end
      end
    end

    context "when key is for a client" do
      it_should_behave_like "common json operations" do
        let(:new_key) { Chef::Key.new("original_actor", "client") }
        let(:json) do
          new_key.to_json
        end
      end
    end

  end # when serializing to JSON

end
