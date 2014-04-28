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

    attr_accessor :attribute,:element,:values,:filter_uri,:new_values


    def initialize(attribute)
      super()
      @attribute = attribute
      @values = {}
      @new_values = {}
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
      div1 = @values.keys - @new_values.keys
      div2 = @new_values.keys - @values.keys

      if (div1.empty? and div2.empty?)
        return true
      else
        return false
      end
    end


    def create_gooddata_muf_representation(pid)
      @new_values.each_pair do |key,value|
        if (key.nil?)
          @@log.warn "The #{value} cannot be found in data loaded to project #{pid} - SKIPPING"
        end
      end
      values = @new_values.keys.map do |k|
        if (!k.nil?)
          "[#{k}]"
        end
      end
      values.delete_if {|k| k.nil?}
      values = values.join(",")
      "[#{Helper.get_element_attribute_url(pid,@attribute)}] IN (#{values})"
    end







  end

end