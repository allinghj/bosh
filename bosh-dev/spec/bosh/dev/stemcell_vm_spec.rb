require 'spec_helper'
require 'bosh/dev/stemcell_vm'

module Bosh::Dev
  describe StemcellVm do
    describe '#publish' do
      let(:options) do
        {
          vm_name: 'remote',
          infrastructure_name: 'fake-infrastructure_name',
          operating_system_name: 'fake-operating_system_name',
        }
      end

      let(:env) do
        {
          'CANDIDATE_BUILD_NUMBER' => 'fake-CANDIDATE_BUILD_NUMBER',
          'BOSH_AWS_ACCESS_KEY_ID' => 'fake-BOSH_AWS_ACCESS_KEY_ID',
          'BOSH_AWS_SECRET_ACCESS_KEY' => 'fake-BOSH_AWS_SECRET_ACCESS_KEY',
          'AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT' =>
            'fake-AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT',
          'AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT' =>
            'fake-AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT',
        }
      end

      subject(:vm) { StemcellVm.new(options, env) }

      before { Rake::FileUtilsExt.stub(:sh) }

      it 'recreates the VM to ensure a clean environment' do
        Rake::FileUtilsExt.should_receive(:sh) do |cmd|
          expect(cmd).to match /vagrant destroy remote --force/
          expect(cmd).to match /vagrant up remote/
        end

        vm.publish
      end

      it 'publishes a stemcell inside the VM' do
        Rake::FileUtilsExt.should_receive(:sh) do |cmd|
          actual = strip_heredoc(cmd)

          expected = strip_heredoc(<<-BASH)
            time vagrant ssh -c "
              set -eu
              cd /bosh
              bundle install --local

              export CANDIDATE_BUILD_NUMBER='fake-CANDIDATE_BUILD_NUMBER'
              export BOSH_AWS_ACCESS_KEY_ID='fake-BOSH_AWS_ACCESS_KEY_ID'
              export BOSH_AWS_SECRET_ACCESS_KEY='fake-BOSH_AWS_SECRET_ACCESS_KEY'
              export AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT='fake-AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT'
              export AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT='fake-AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT'
              export AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT='fake-AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT'

              time bundle exec rake ci:publish_stemcell[fake-infrastructure_name,fake-operating_system_name]
            " remote
          BASH

          expect(actual).to include(expected)
        end

        vm.publish
      end

      context 'when the UBUNTU_ISO is (optionally) specified' do
        before { env['UBUNTU_ISO'] = 'fake-UBUNTU_ISO' }

        it 'exports UBUNTU_ISO for vagrant ssh -c' do
          Rake::FileUtilsExt.should_receive(:sh).with(/export UBUNTU_ISO='fake-UBUNTU_ISO'/)

          vm.publish
        end
      end

      it 'fails early' do
        Rake::FileUtilsExt.should_receive(:sh).with(/set -eu/)

        vm.publish
      end

      context 'when the vm is "remote"' do
        before { options[:vm_name] = 'remote' }

        it 'uses the "aws" provider' do
          Rake::FileUtilsExt.should_receive(:sh).with(/vagrant up remote --provider aws/)
          vm.publish
        end
      end

      context 'when the vm is "local"' do
        before { options[:vm_name] = 'local' }

        it 'uses the "virtualbox" provider' do
          Rake::FileUtilsExt.should_receive(:sh).with(/vagrant up local --provider virtualbox/)
          vm.publish
        end
      end

      context 'when the vm is "anything-else"' do
        before { options[:vm_name] = 'unrecognized-name' }

        it 'raises an error' do
          expect { vm.publish }.to raise_error(/must be 'local' or 'remote'/)
        end
      end
    end

    def strip_heredoc(str)
      indent = str.scan(/^[ \t]*(?=\S)/).min.size
      str.gsub(/^[ \t]{#{indent}}/, '')
    end
  end
end