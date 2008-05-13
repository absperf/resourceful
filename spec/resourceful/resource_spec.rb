require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/resource'

describe Resourceful::Resource do
  before do
    @accessor = mock('http_accessor')
    @uri      = 'http://www.example.com/'
    @resource = Resourceful::Resource.new(@accessor, @uri)

    @response = mock('response', :code => 200, :is_redirect? => false)

    @request = mock('request', :response => @response, :should_be_redirected? => true)
    Resourceful::Request.stub!(:new).and_return(@request)
  end

  describe 'init' do
    it 'should be instantiatable' do
      @resource.should be_instance_of(Resourceful::Resource)
    end

    it 'should take an http_accessor' do
      @resource.accessor.should == @accessor
    end

    it 'should take a uri' do
      @resource.uri.should == @uri
    end
  end

  describe '#effective_uri' do

    it 'should be the latest uri' do
      @resource.effective_uri.should == @uri
    end

    it 'should be aliased as #uri' do
      @resource.uri.should == @resource.effective_uri
    end

  end

  describe '#do_read_request' do

    it 'should make a new request object from the method' do
      Resourceful::Request.should_receive(:new).with(:some_method, @resource).and_return(@request)
      @resource.do_read_request(:some_method)
    end

    describe 'with redirection' do
      before do
        @uri      = 'http://www.example.com/redirect/301?http://www.example.com/get'
        @resource = Resourceful::Resource.new(@accessor, @uri)

        @redirected_uri = 'http://www.example.com/get'
        @redirect_response = mock('redirect_response',
                                  :header                 => {'Location' => [@redirected_uri]},
                                  :is_redirect?           => true,
                                  :is_permanent_redirect? => true)

        @request.stub!(:response).and_return(@redirect_response, @response)

      end

      def make_request
        @resource.do_read_request(:some_method)
      end

      it 'should check if the response was a redirect' do
        @redirect_response.should_receive(:is_redirect?).and_return(true)
        make_request
      end

      it 'should check if the request should be redirected' do
        @request.should_receive(:should_be_redirected?).and_return(true)
        make_request
      end

      describe 'permanent redirect' do
        before do
          @redirect_response.stub!(:is_permanent_redirect?).and_return(true)
        end

        it 'should check if the response was a permanent redirect' do
          @redirect_response.should_receive(:is_permanent_redirect?).and_return(true)
          make_request
        end

        it 'should add the new location as the effective uri' do
          make_request
          @resource.effective_uri.should == @redirected_uri
        end

        it 'should remake the request with the new uri' do
          Resourceful::Request.should_receive(:new).twice.and_return(@request)
          @request.should_receive(:response).twice.and_return(@redirect_response, @response)
          make_request
        end

      end

      describe 'temporary redirect' do
        before do
          @redirect_response.stub!(:is_permanent_redirect?).and_return(false)
        end

        it 'should check if the response was not a permanent redirect' do
          @redirect_response.should_receive(:is_permanent_redirect?).and_return(false)
          make_request
        end

        it 'should not add the new location as the effective uri' do
          make_request
          @resource.effective_uri.should == @uri
        end
        
        it 'should make a new resource from the new location' do
          new_resource = mock('resource', :do_read_request => @response)
          Resourceful::Resource.should_receive(:new).with(@accessor, @redirected_uri).and_return(new_resource)
          make_request
        end

      end

    end # read with redirection

  end

  describe '#do_write_request' do

    it 'should make a new request object from the method' do
      Resourceful::Request.should_receive(:new).with(:some_method, @resource, "data").and_return(@request)
      @resource.do_write_request(:some_method, "data")
    end

    describe 'with redirection' do
      before do
        @uri      = 'http://www.example.com/redirect/301?http://www.example.com/get'
        @resource = Resourceful::Resource.new(@accessor, @uri)

        @redirected_uri = 'http://www.example.com/get'
        @redirect_response = mock('redirect_response',
                                  :header                 => {'Location' => [@redirected_uri]},
                                  :is_redirect?           => true,
                                  :is_permanent_redirect? => true)

        @request.stub!(:response).and_return(@redirect_response, @response)

      end

      def make_request
        @resource.do_write_request(:some_method, "data")
      end

      it 'should check if the response was a redirect' do
        @redirect_response.should_receive(:is_redirect?).and_return(true)
        make_request
      end

      it 'should check if the request should be redirected' do
        @request.should_receive(:should_be_redirected?).and_return(true)
        make_request
      end

      describe 'permanent redirect' do
        before do
          @redirect_response.stub!(:is_permanent_redirect?).and_return(true)
        end

        it 'should check if the response was a permanent redirect' do
          @redirect_response.should_receive(:is_permanent_redirect?).and_return(true)
          make_request
        end

        it 'should add the new location as the effective uri' do
          make_request
          @resource.effective_uri.should == @redirected_uri
        end

        it 'should remake the request with the new uri' do
          Resourceful::Request.should_receive(:new).twice.and_return(@request)
          @request.should_receive(:response).twice.and_return(@redirect_response, @response)
          make_request
        end

      end

      describe 'temporary redirect' do
        before do
          @redirect_response.stub!(:is_permanent_redirect?).and_return(false)
        end

        it 'should check if the response was not a permanent redirect' do
          @redirect_response.should_receive(:is_permanent_redirect?).and_return(false)
          make_request
        end

        it 'should not add the new location as the effective uri' do
          make_request
          @resource.effective_uri.should == @uri
        end
        
        it 'should make a new resource from the new location' do
          new_resource = mock('resource', :do_write_request => @response)
          Resourceful::Resource.should_receive(:new).with(@accessor, @redirected_uri).and_return(new_resource)
          make_request
        end

      end

    end # write with redirection

  end

  describe 'callback registration' do
    before do
      @callback = mock('callback')
      @callback.stub!(:call).and_return(true)

      @resource.on_redirect { @callback.call }
    end

    it 'should store the callback when called with a block' do
      @resource.on_redirect { true }

      callback = @resource.instance_variable_get(:@on_redirect)
      callback.should be_kind_of(Proc)
    end

    it 'should return the callback when called without a block' do
      @resource.on_redirect { true }
      @resource.on_redirect.should be_kind_of(Proc)
    end

    it 'should yield the request,response to the callback' do
      @resource.on_redirect { |req,resp|
        req.should == @request
        resp.should == @redirect_response
      }

      @resource.get
    end
  end

  describe '#get' do

    it 'should be a method' do
      @resource.should respond_to(:get)
    end

    it 'should pass :get to the #do_read_request method' do
      @resource.should_receive(:do_read_request).with(:get)
      @resource.get
    end

    it 'should return the response of making the request' do
      @resource.get.should == @response
    end

  end

  %w{post put}.each do |method|
    describe "##{method}" do

      it 'should be a method' do
        @resource.should respond_to(method.intern)
      end
      
      it 'should return the response of making the request' do
        @resource.send(method.intern, "Hello from #{method.upcase}!").should == @response
      end

    end
  end

  describe "#delete" do

    it 'should be a method' do
      @resource.should respond_to(:delete)
    end

    it 'should return the response of making the request' do
      @resource.delete.should == @response
    end

  end

end

