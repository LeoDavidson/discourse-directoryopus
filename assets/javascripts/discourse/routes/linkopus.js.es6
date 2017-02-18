import { ajax } from 'discourse/lib/ajax';
import { extractError } from 'discourse/lib/ajax-error';

export default Discourse.Route.extend({

	model() {
		return this.modelFor("user");
	},

	afterModel(userModel) {
		// If a normal user tries to view users/<username>/link-opus for another account,
		// send them to that account's summary page instead, as a convenience. This is not
		// for security as nothing on the javascript side can be relied on for security.
		// Since admins have can_edit for all users, they can see the linking page for anyone.
		if (!userModel.get("can_edit")) {
			this.replaceWith("user.summary");
		}

		// loading = true;
		const username = userModel.get("username");
		const userid = userModel.get("id");
		
		if (userModel.get("opuslinkLoadResult")) {
			userModel.set("opuslinkLoadError", "That's odd...");
		}
		else {
			// Start the ajax/json request, which is async.
			// When/if it finishes successfully, store the json results on the model.
			// If it fails, set a failure error message that is displayed instead.
			ajax("/users/" + username + "/link-opus.json?user_id=" + userid).
				then(jsonResult => { userModel.set("opuslinkLoadResult", jsonResult); } ).
				catch(ajaxError => { userModel.set("opuslinkLoadError", extractError(ajaxError)); });
		}
	},

	setupController(controller, userModel) {
		controller.set('model', userModel);
	},

	titleToken() {
 		return I18n.t("directoryopus.linkopus_title");
	},

	renderTemplate() {
		this.render("linkopus");
	},
});
