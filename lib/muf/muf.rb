# Copyright (c) 2009, GoodData Corporation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
# Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
# Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
# Neither the name of the GoodData Corporation nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS
# OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.



module PowerByHelper

  class Muf

    attr_accessor :attribute,:element,:values,:filter_uri,:new_values,:type,:muf_url


    def initialize(attribute,muf_url,options = {})
      super()
      @attribute = attribute
      @values = {}
      @new_values = {}
      @option = options
      @muf_url = muf_url
    end

    def add_value(element_id,value)
      @values[element_id] = value
    end

    def add_new_values(element_id,value)
      @new_values[element_id] = value
    end

    def has_value?(element_id)
      @values.has_key?(element_id)
    end

    def same?
      fail "Calling method from parent"
    end


    def create_gooddata_muf_representation(pid,options = {})
      fail "Calling method from parent"
    end


    state_machine :state, :initial => :start do
      state :start
      state :create
      state :ok
      state :to_delete
      state :changed


      event :to_delete do
        transition :start => :to_delete,[:ok,:create] => :changed
      end

      event :same do
        transition :start => :ok,[:to_delete,:create] => :changed
      end

      event :new do
        transition :start => :create,[:ok,:to_delete] => :changed
      end

      event :change do
        transition [:start,:ok,:create] => :changed
      end

      event :clear do
        transition all => :start
      end



    end







  end

end