#require "spec_setup"
#require "fpm/package/nuget" # local

#describe FPM::Package::Nuget do
describe "FPM::Package::Nuget" do
  # let (:example_nuget) do
  #   File.expand_path("../../fixtures/nuget/example/example-1.0.nuget", File.dirname(__FILE__))
  # end

  # Test the different options:
  # http://docs.nuget.org/docs/reference/versioning#Specifying_Version_Ranges_in_.nuspec_Files
  #
  # In short, pass a dependency to fpm as a string with minimum 1 and up to 3 parts
  # separated by spaces, e.g.:
  # fpm -d "MyDependency" ...            -> <dependency id="MyDependency" version=""/>
  # fpm -d "MyDependency 1.0" ...        -> <dependency id="MyDependency" version="1.0"/>
  # fpm -d "MyDependency 1.0 (,2.0)" ... -> <dependency id="MyDependency" version="1.0" allowedVersions="(,2.0)"/>

  describe "#fix_dependency" do

    context "with normal versions" do
      it "should accept 'MyDependency'" do
        fail()
      end
    end

    context "with normal versions" do
      it "should accept 'MyDependency 1'" do
        fail()
      end

      it "should accept 'MyDependency 1.2'" do
        fail()
      end

      it "should accept 'MyDependency 1.2.3'" do
        fail()
      end

      it "should accept 'MyDependency [1.2.3]'" do
        fail()
      end

      it "should fail on 'MyDependency (1.2.3)'" do
        fail()
      end

      it "should accept 'MyDependency (,1.2]'" do
        fail()
      end

      it "should accept 'MyDependency (,1.2.3)'" do
        fail()
      end

      it "should accept 'MyDependency (1.2,)'" do
        fail()
      end

      it "should accept 'MyDependency (1.2,2.0)'" do
        fail()
      end

      it "should accept 'MyDependency [1.2,2.0]'" do
        fail()
      end
    end

    # http://docs.nuget.org/docs/reference/versioning#Constraining_Upgrades_To_Allowed_Versions
    context "with allowed versions" do
      it "should accept 'MyDependency 1 2'" do
        fail()
      end

      it "should accept 'MyDependency 1.2 (,2.0)'" do
        fail()
      end

      it "should accept 'MyDependency 1.2.3' (,2.0)" do
        fail()
      end

      it "should accept 'MyDependency [1.2.3]' (,2.0)" do
        fail()
      end

      it "should fail on 'MyDependency (1.2.3) (,2.0)'" do
        fail()
      end

      it "should accept 'MyDependency (,1.2] (,2.0)'" do
        fail()
      end

      it "should accept 'MyDependency (,1.2.3) (,2.0)'" do
        fail()
      end

      it "should accept 'MyDependency (1.2,) (,2.0)'" do
        fail()
      end

      it "should accept 'MyDependency (1.2,2.0) (,3.0)'" do
        fail()
      end

      it "should accept 'MyDependency [1.2,2.0] (,3.0)'" do
        fail()
      end
    end
  end

  # after :each do
  #   subject.cleanup
  # end

end # describe FPM::Package::Nuget
