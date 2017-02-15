import { ajax } from 'discourse/lib/ajax';

export default Discourse.Route.extend({

  model() {
    const userModel = this.modelFor("user");
    const username = userModel.get("username");
    const userid = userModel.get("id");
    return ajax("/users/" + username + "/link-opus.json?user_id=" + userid);
  },

  beforeModel() {
    // If a normal user tries to view users/<username>/link-opus for another account,
    // send them to that account's summary page instead, as a convenience. This is not
    // for security as nothing on the javascript side can be relied on for security.
    // Since admins have can_edit for all users, they can see the linking page for anyone.
    if (!this.modelFor("user").get("can_edit")) {
      this.replaceWith("user.summary");
    }
  },

  titleToken() {
    return I18n.t("directoryopus.linkopus_title");
  },

  renderTemplate() {
    this.render("linkopus");
  },
});
