import { ajax } from 'discourse/lib/ajax';
import { extractError } from 'discourse/lib/ajax-error';
//import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
	application: Ember.inject.controller(),
	ajaxPending: false,
	opuslinkLoadError: null,
	opuslinkLoadResult: null,

	startLinkQuery() {

		if (this.get("ajaxPending")) {
			return;
		}

		const userModel = this.get("model");
		if (typeof userModel === "undefined") {
			return;
		}
		const username = userModel.get("username");
		const userid = userModel.get("id");
		
		this.set("ajaxPending",true);

		// Start the ajax/json request, which is async.
		// When/if it finishes successfully, store the json results on the model.
		// If it fails, set a failure error message that is displayed instead.
		ajax("/users/" + username + "/link-opus.json?user_id=" + userid, { type: 'GET', cache: false }).
			then(jsonResult => this.onLinkQuerySuccess(jsonResult)).
			catch(ajaxError => this.onLinkQueryFailure(ajaxError));
	},

	onLinkQuerySuccess(jsonResult) {
		this.set("opuslinkLoadError", null);
		this.set("opuslinkLoadResult", jsonResult);
		this.set("ajaxPending",false);
	},

	onLinkQueryFailure(ajaxError) {
		this.set("opuslinkLoadResult", null);
		this.set("opuslinkLoadError", extractError(ajaxError));
		this.set("ajaxPending",false);
	},
});
