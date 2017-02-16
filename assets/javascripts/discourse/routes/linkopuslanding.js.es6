export default Discourse.Route.extend({

  beforeModel() {
    // If a user is logged in, take them to their personal account-linking page.
    // Otherwise, we'll display the landing page with instructions on what to do.
    if (this.currentUser) {
      this.replaceWith("/users/" + this.currentUser.get("username") + "/link-opus");
    }
  },

  titleToken() {
    return I18n.t("directoryopus.linkopus_title");
  },

  renderTemplate() {
    this.render("linkopuslanding");
  },

  actions: {
    didTransition() {
      this.controllerFor("application").set("showFooter", true);
      return true;
    }
  }
});
