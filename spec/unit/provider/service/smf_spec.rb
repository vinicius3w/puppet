#!/usr/bin/env ruby
#
# Unit testing for the SMF service Provider
#
# author Dominic Cleal
#
require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')

provider_class = Puppet::Type.type(:service).provider(:smf)

describe provider_class do

  before(:each) do
    # Create a mock resource
    @resource = stub 'resource'
    @provider = provider_class.new(@resource)

    @resource.stubs(:[]).returns(nil)
    @resource.stubs(:[]).with(:name).returns "/system/myservice"
    @resource.stubs(:[]).with(:ensure).returns :enabled
    @resource.stubs(:[]).with(:enable).returns :true
    @resource.stubs(:name).returns "/system/myservice"
    @resource.stubs(:ref).returns "Service[/system/myservice]"
    @provider.stubs(:resource).returns @resource

    FileTest.stubs(:file?).with('/usr/sbin/svcadm').returns true
    FileTest.stubs(:executable?).with('/usr/sbin/svcadm').returns true
    FileTest.stubs(:file?).with('/usr/bin/svcs').returns true
    FileTest.stubs(:executable?).with('/usr/bin/svcs').returns true
  end

  it "should have a restart method" do
    @provider.should respond_to(:restart)
  end

  it "should have a restartcmd method" do
    @provider.should respond_to(:restartcmd)
  end

  it "should have a start method" do
    @provider.should respond_to(:start)
  end

  it "should have a stop method" do
    @provider.should respond_to(:stop)
  end

  it "should have an enabled? method" do
    @provider.should respond_to(:enabled?)
  end

  it "should have an enable method" do
    @provider.should respond_to(:enable)
  end

  it "should have a disable method" do
    @provider.should respond_to(:disable)
  end

  describe "when checking status" do
    it "should call the external command 'svcs /system/myservice' once" do
      @provider.expects(:svcs).with('-H', '-o', 'state,nstate', "/system/myservice").returns("online\t-")
      @provider.status
    end
    it "should return stopped if svcs can't find the service" do
      @provider.stubs(:svcs).raises(Puppet::ExecutionFailure.new("no svc found"))
      @provider.status.should == :stopped
    end
    it "should return running if online in svcs output" do
      @provider.stubs(:svcs).returns("online\t-")
      @provider.status.should == :running
    end
    it "should return stopped if disabled in svcs output" do
      @provider.stubs(:svcs).returns("disabled\t-")
      @provider.status.should == :stopped
    end
    it "should return maintenance if in maintenance in svcs output" do
      @provider.stubs(:svcs).returns("maintenance\t-")
      @provider.status.should == :maintenance
    end
    it "should return target state if transitioning in svcs output" do
      @provider.stubs(:svcs).returns("online\tdisabled")
      @provider.status.should == :stopped
    end
    it "should throw error if it's a legacy service in svcs output" do
      @provider.stubs(:svcs).returns("legacy_run\t-")
      lambda { @provider.status }.should raise_error(Puppet::Error, "Cannot manage legacy services through SMF")
    end
  end

  describe "when starting" do
    it "should enable the service if it is not enabled" do
      @provider.expects(:status).returns :stopped
      @provider.expects(:texecute)
      @provider.start
    end

    it "should always execute external command 'svcadm enable /system/myservice'" do
      @provider.stubs(:status).returns :running
      @provider.expects(:texecute).with(:start, ["/usr/sbin/svcadm", :enable, "/system/myservice"], true)
      @provider.start
    end

    it "should execute external command 'svcadm clear /system/myservice' if in maintenance" do
      @provider.stubs(:status).returns :maintenance
      @provider.expects(:texecute).with(:start, ["/usr/sbin/svcadm", :clear, "/system/myservice"], true)
      @provider.start
    end

    it "should import the manifest if service is not found" do
      @resource.stubs(:[]).with(:manifest).returns("/tmp/myservice.xml")
      $CHILD_STATUS.stubs(:exitstatus).returns(1)
      @provider.expects(:svccfg).with(:import, "/tmp/myservice.xml")
      @provider.expects(:texecute).with(:start, ["/usr/sbin/svcadm", :enable, "/system/myservice"], true)
      @provider.start
    end
  end

  describe "when stopping" do
    it "should execute external command 'svcadm disable /system/myservice'" do
      @provider.expects(:texecute).with(:stop, ["/usr/sbin/svcadm", :disable, "/system/myservice"], true)
      @provider.stop
    end
  end

  describe "when restarting" do
    it "should call 'svcadm restart /system/myservice'" do
      @provider.expects(:texecute).with(:restart, ["/usr/sbin/svcadm", :restart, "/system/myservice"], true)
      @provider.restart
    end
  end

end
