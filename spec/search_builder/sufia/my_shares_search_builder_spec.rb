describe Sufia::MySharesSearchBuilder do
  let(:me) { create(:user) }
  let(:config) { CatalogController.blacklight_config }
  let(:scope) do
    double('The scope',
           blacklight_config: config,
           params: {},
           current_ability: Ability.new(me),
           current_user: me)
  end
  let(:builder) { described_class.new(scope) }

  let(:solr_params) { { q: user_query } }

  before do
    allow(builder).to receive(:gated_discovery_filters).and_return(["access_filter1", "access_filter2"])
    allow(ActiveFedora::SolrQueryBuilder).to receive(:construct_query_for_rel)
      .with(depositor: me.user_key)
      .and_return("depositor")
    allow(Flipflop).to receive(:enable_mediated_deposit?).and_return(mediation_enabled)
  end

  let(:mediation_enabled) { false }
  subject { builder.to_hash['fq'] }

  it "filters things we have access to in which we are not the depositor" do
    expect(subject).to eq ["access_filter1 OR access_filter2",
                           "{!terms f=has_model_ssim}GenericWork,Collection",
                           "-depositor"]
  end

  describe "mediated deposit" do
    let(:user_query) { nil }

    context "with mediated deposit enabled" do
      let(:mediation_enabled) { true }
      it "does includes suppressed switch" do
        builder.show_only_shared_files(solr_params)
        expect(solr_params[:fq]).to eq ["-depositor", "-suppressed_bsi:true"]
      end
    end

    context "with mediated deposit disabled" do
      let(:mediation_enabled) { false }
      it "does not include suppressed switch" do
        builder.show_only_shared_files(solr_params)
        expect(solr_params[:fq]).to eq ["-depositor"]
      end
    end
  end
end
