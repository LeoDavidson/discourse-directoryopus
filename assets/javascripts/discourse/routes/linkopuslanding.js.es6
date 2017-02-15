export default Discourse.Route.extend({

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
