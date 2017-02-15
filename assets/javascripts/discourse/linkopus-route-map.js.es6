export default {

  // We want to put this route under the existing /users/<username>/ level, as
  // /users/<username>/link-opus
  
  // The "resource" attribute identifies the existing branch to add things under. For the list of branches, see:
  //   https://github.com/discourse/discourse/blob/master/app/assets/javascripts/discourse/routes/app-route-map.js.es6
  //   https://github.com/discourse/discourse/blob/master/app/assets/javascripts/admin/routes/admin-route-map.js.es6
  // (Note that if you want something under the root, you return the map function itself as the default export, not an object.)

  // The "path" attribute is needed where the route and URL components differ.
  // e.g. The "user" route needs a username in the URL which is of the form "users/:username" e.g. "users/leo".
  // e.g. The "linkopus" route uses the URL "link-opus". (I didn't want the URL to be "linkopus" and the server and client
  //      sides do different things with mixed case, dashes, underscores and multiple words in general which complicates
  //      things, so I am trying to avoid it unless it's something the user actually sees, like the URL.)

  // resetNamespace makes it so our route is called just "linkopus" and not "user.linkopus" or something.
  // There then needs to be a corresponding routes/linkopus.js.es6 file in our plugin that handles the route.

  resource: 'user',
  path: 'users/:username',
  map() {
     this.route('linkopus', { path: 'link-opus', resetNamespace: true });
  }
};
