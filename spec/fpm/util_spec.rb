require "spec_setup"
require "fpm" # local
require "fpm/util" # local
require "stud/temporary"


describe FPM::Util do
  subject do
    Class.new do
      include FPM::Util
      def initialize
        @logger = Cabin::Channel.new
      end
    end.new
  end

  context "#copy_entry" do
    context "when given files that are hardlinks" do
      it "should keep those files as hardlinks" do
        Stud::Temporary.directory do |path|
          a = File.join(path, "a")
          b = File.join(path, "b")
          File.write(a, "hello")
          File.link(a, b)

          Stud::Temporary.directory do |target|
            ta = File.join(target, "a")
            tb = File.join(target, "b")
            subject.copy_entry(a, ta)
            subject.copy_entry(b, tb)

            # This seems to work to compare file stat calls.
            # target 'a' and 'b' should have the same stat result because
            # they are linked to the same file.
            insist { File.lstat(ta) } == File.lstat(tb)
          end
        end
      end
    end
  end # #copy_entry

  describe "#safesystem" do
    context "with a missing $SHELL" do
      before do
        @orig_shell = ENV["SHELL"]
        ENV.delete("SHELL")
      end

      after do
        ENV["SHELL"] = @orig_shell unless @orig_shell.nil?
      end

      it "should assume /bin/sh"  do
        insist { subject.default_shell } == "/bin/sh"
      end

      it "should still run commands correctly" do
        # This will raise an exception if we can't run it at all.
        subject.safesystem("true")
      end
    end
    context "with $SHELL set to an empty string" do 
      before do
        @orig_shell = ENV["SHELL"]
        ENV["SHELL"] = ""
      end

      after do
        ENV["SHELL"] = @orig_shell unless @orig_shell.nil?
      end

      it "should assume /bin/sh"  do
        insist { subject.default_shell } == "/bin/sh"
      end

      it "should still run commands correctly" do
        # This will raise an exception if we can't run it at all.
        subject.safesystem("true")
      end
    end
  end

  describe "#expand_pessimistic_constraints" do
    it 'convert 2 piece versions' do
      constraint = 'bundle ~> 1.2'

      expected_lower = 'bundle >= 1.2'
      expected_upper =  'bundle < 2.0'

      derived_constraint = subject.expand_pessimistic_constraints(constraint)

      expect(derived_constraint).to include expected_lower
      expect(derived_constraint).to include expected_upper
    end

    it 'convert 3 piece versions' do
      constraint = 'zippy ~> 1.2.3'

      expected_lower = 'zippy >= 1.2.3'
      expected_upper =  'zippy < 1.3.0'

      derived_constraint = subject.expand_pessimistic_constraints(constraint)

      expect(derived_constraint).to include expected_lower
      expect(derived_constraint).to include expected_upper
    end

    it 'does not convert where not needed when the operator is > ' do
      constraint = 'zippy > 1.2.3'
      derived_constraint = subject.expand_pessimistic_constraints(constraint)
      expect(derived_constraint).to include constraint
    end

    it 'does not convert where not needed when when the operator is < ' do
      constraint = 'zippy < 1.2.3'
      derived_constraint = subject.expand_pessimistic_constraints(constraint)
      expect(derived_constraint).to include constraint
    end

    it 'does not convert where not needed when when the operator is <= ' do
      constraint = 'zippy <= 1.2.3'
      derived_constraint = subject.expand_pessimistic_constraints(constraint)
      expect(derived_constraint).to include constraint
    end

    it 'does not convert where not needed when when the operator is >= ' do
      constraint = 'zippy >= 1.2.3'
      derived_constraint = subject.expand_pessimistic_constraints(constraint)
      expect(derived_constraint).to include constraint
    end
  end
end
