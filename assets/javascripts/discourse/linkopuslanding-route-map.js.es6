// To add routes to the root, return the map function itself rather than an object with a map function member.
export default function() {
	this.route('linkopuslanding', { path: '/link-opus', resetNamespace: true });
}
