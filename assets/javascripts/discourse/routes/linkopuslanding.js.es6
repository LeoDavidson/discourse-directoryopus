export default Discourse.Route.extend({

	beforeModel() {
		// If a user is logged in, take them to their personal account-linking page.
		// Otherwise, we'll display the landing page with instructions on what to do.
		if (this.currentUser) {
			this.replaceWith("/u/" + this.currentUser.get("username") + "/link-opus");
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
