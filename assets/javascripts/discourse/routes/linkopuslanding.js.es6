export default Discourse.Route.extend({

	beforeModel() {
		// If a user is logged in, take them to their personal account-linking page.
		// Otherwise, we'll display the landing page with instructions on what to do.
		if (this.currentUser) {
			// This stopped working around Discourse v1.8.0.beta11+3. I can't work out why.
			// You end up with the correct URL but an "oops, that page is missing / private" error.
			// Yet if you simply click refresh or push F5, the page loads correctly.
			// At least for now, we will fall back on using window.location.assign to divert
			// to the other URL at a higher level, which isn't as nice as you see the landing
			// page saying your account isn't linked yet for e moment before the new page loads.

			// this.replaceWith("/users/" + this.currentUser.get("username") + "/link-opus");

			window.location.assign("/users/" + this.currentUser.get("username") + "/link-opus");
		}
	},

	model() {
		return null;
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

	actions: {
		didTransition() {
			this.controllerFor("application").set("showFooter", true);
			return true;
		}
	}
});
