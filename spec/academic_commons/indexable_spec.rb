require 'rails_helper'
RSpec.describe AcademicCommons::Indexable do
  let(:expected_json) { JSON.load File.read('spec/fixtures/actest_1/to_solr.json') }
  let(:indexable) do
    class_rig = Class.new
    class_rig.class_eval do
      include AcademicCommons::Indexable
      def belongs_to; end
      def descMetadata_datastream; end
      def pid; end
    end
    indexable = class_rig.new
    allow(indexable).to receive(:pid).and_return('actest:1')
    allow(indexable).to receive(:belongs_to).and_return(['collection:3'])

    ds_fixture = ActiveFedora::Datastream.new(indexable, 'test_ds')
    allow(ds_fixture).to receive(:content).and_return mods_fixture
    allow(indexable).to receive(:descMetadata_datastream).and_return ds_fixture

    indexable
  end

  shared_examples 'indexing mods' do
    subject { indexable.index_descMetadata }

    describe "#index_descMetadata" do
      it  { is_expected.to eql(expected_json) }
    end
  end

  # Tests prefixed MODS with joined names. These changes were introduced with the
  # migration to Hyacinth.
  context 'when mods from Hyacinth' do
    let(:mods_fixture) { File.read('spec/fixtures/actest_3/mods.xml') }

    include_examples 'indexing mods'
  end

  # TODO: This can test and its associated fixture can be removed when we
  # completely transition over to Hyacinth.
  context 'when mods from Hypatia' do
    let(:mods_fixture) { File.read('spec/fixtures/hypatia_mods.xml') }
    include_examples 'indexing mods'
  end
end
