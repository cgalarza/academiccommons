require 'rails_helper'

RSpec.describe AcademicCommons::Metrics::ItemStats do
  subject(:item_stats) { described_class.new(doc) }

  let(:doi) { '10.7916/ALICE' }
  let(:doc) { SolrDocument.new(id: doi) }

  describe '.new' do
    its(:document) { is_expected.to eq doc }
    its(:id)       { is_expected.to eq doi }
  end

  describe '#get_stat' do
    before do
      item_stats.add_stat(Statistic::VIEW, 'Jan 2001', 178)
    end

    it 'returns correct value' do
      expect(item_stats.get_stat(Statistic::VIEW, 'Jan 2001')).to eq 178
    end

    it 'synonymous method returns correct value' do
      expect(item_stats.number_of_views('Jan 2001')).to eq 178
    end

    it 'returns error if parameters not valid' do
      expect {
        item_stats.get_stat(Statistic::VIEW, 'Feb 2001')
      }.to raise_error 'View Feb 2001 not part of stats. Check parameters.'
    end
  end

  describe '#add_stat' do
    it 'updates stats hash' do
      item_stats.add_stat(Statistic::DOWNLOAD, 'June 2003', 14)
      expect(item_stats.stats).to match(
        Statistic::VIEW => {},
        Statistic::DOWNLOAD => { 'June 2003' => 14 },
        Statistic::STREAM => {}
      )
    end
  end

  describe '#zero?' do
    context 'when there are stats present when all stats are 0' do
      before do
        item_stats.add_stat(Statistic::VIEW, 'Lifetime', 14)
      end

      it 'returns false' do
        expect(item_stats.zero?).to eq false
      end
    end

    context 'when all stats are 0' do
      it 'return false' do
        expect(item_stats.zero?).to eq true
      end
    end
  end
end
