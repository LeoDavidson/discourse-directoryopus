import { ajax } from 'discourse/lib/ajax';
import { extractError } from 'discourse/lib/ajax-error';
//import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
	application: Ember.inject.controller(),
	opuslinkAjaxPending: false,
	opuslinkLoadError: null,
	opuslinkLoadResult: null,
	opuslinkRegCodeShowMe: false,
	opuslinkRegCodeExample: false,
	opuslinkRegCodeInput: "",

	startLinkQuery(operationName, regCode) {

		if (this.get("opuslinkAjaxPending")) {
			return;
		}

		if (window.location.protocol !== "https:" && Discourse.Environment !== "development") {
			this.set("opuslinkLoadError", "Submission over http:// is not secure. Please use the site's https:// URL");
			this.set("opuslinkLoadResult", null); // Should be redundant.
			return;
		}

		const userModel = this.get("model");
		if (typeof userModel === "undefined" || userModel === null) {
			return;
		}
		const username = userModel.get("username");
		const userid = userModel.get("id");
		
		this.set("opuslinkAjaxPending",true);

		var dataParams = {
			user_id: userid,
			operation: operationName,
			reg_code: regCode,
		};

		// Filter out null parameters. n.b. Can use _.pickBy(obj) with lodash 4, but Discourse seems to be on 1.3.
		dataParams = _.pick(dataParams, _.identity);

		// Start the ajax/json request, which is async.
		// When/if it finishes successfully, store the json results on the model.
		// If it fails, set a failure error message that is displayed instead.
		ajax("/users/" + username + "/link-opus.json", {
				type: 'GET',
				cache: false,
				data: dataParams,
			}).
			then(jsonResult => this.onLinkQuerySuccess(jsonResult)).
			catch(ajaxError => this.onLinkQueryFailure(ajaxError));
	},

	onLinkQuerySuccess(jsonResult) {
		if (typeof jsonResult["link_edition"] === "string" && jsonResult["link_edition"].toLowerCase() === "pro") {
			jsonResult["link_edition"] = "Pro"; // For the capital letter.
			jsonResult["link_edition_class"] = "directoryopus-link-edition-pro";
		}
		else if (typeof jsonResult["link_edition"] === "string" && jsonResult["link_edition"].toLowerCase() === "light") {
			jsonResult["link_edition"] = "Light"; // For the capital letter.
			jsonResult["link_edition_class"] = "directoryopus-link-edition-light";
		}
		else {
			jsonResult["link_edition_class"] = "directoryopus-link-edition";
		}
		if (typeof jsonResult["link_reg_code_redacted"] === "string" || typeof jsonResult["link_reg_date"] === "string") {
			jsonResult["link_refresh_details_title"] = "Refresh Details";
		}
		else {
			jsonResult["link_refresh_details_title"] = "Load Details";
		}
		if (typeof jsonResult["link_reg_date"] === "string") {
			jsonResult["link_reg_date"] = jsonResult["link_reg_date"] + " TODO: Convert this";
		}
		this.set("opuslinkRegCodeExample", false);
		this.set("opuslinkLoadError", null);
		this.set("opuslinkLoadResult", jsonResult);
		this.set("opuslinkAjaxPending",false);
	},

	onLinkQueryFailure(ajaxError) {
		this.set("opuslinkRegCodeExample", false);
		this.set("opuslinkLoadError", extractError(ajaxError));
		this.set("opuslinkLoadResult", null);
		this.set("opuslinkAjaxPending",false);
	},

	getRegCode() {
		const regCodeOrig = this.get("opuslinkRegCodeInput");
		if (typeof regCodeOrig !== "string") {
			return null;
			}
		// Trim spaces, convert to uppercase, and add the dashes if any are missing.
		// The server side is much more strict, as it expects us to have done this already.
		var regCode = regCodeOrig.trim().toUpperCase().replace(/^([A-Z0-9]{5})-?([A-Z0-9]{5})-?([A-Z0-9]{5})-?([A-Z0-9]{5})$/, "$1-$2-$3-$4");
		if (regCode !== regCodeOrig) {
			this.set("opuslinkRegCodeInput", regCode);
		}
		return regCode;
	},

	validateRegCode(regCode) {
		if (typeof regCode !== "string") {
			return false;
		}
		if (! /^[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}$/.test(regCode) ) {
			return false;
		}
		return true;
	},

	setErrorMessage(errMsg) {
		// Note that we are sometimes called with errMsg null to clear both messages.
		const existingRes = this.get("opuslinkLoadResult");
		if (typeof existingRes === "undefined" || existingRes === null) {
			this.set("opuslinkLoadError", errMsg);
		}
		else {
			this.set("opuslinkLoadResult.remote_error", errMsg);
			this.set("opuslinkLoadError", null);
		}
	},
	
	actions: {
		onOpusLinkSubmitRegCode() {
			if (this.get("opuslinkAjaxPending")) {
				return;
			}
			
			const regCode = this.getRegCode();
			if (regCode === "") {
				this.setErrorMessage("You must enter a registration code.");
				this.set("opuslinkRegCodeExample", true);
				return;
			}
			if (!this.validateRegCode(regCode)) {
				this.setErrorMessage("\"" + regCode + "\" is not the correct format for a registration code.");
				this.set("opuslinkRegCodeExample", true);
				return;
			}
			if (regCode === "ABC12-DE3FG-4HIJ5-KL6M7") {
				this.setErrorMessage("You can't use the example registration code. It's just an example. Don't be silly.");
				this.set("opuslinkRegCodeExample", false);
				return;
			}
			this.setErrorMessage(null);
			this.set("opuslinkRegCodeShowMe", false); // So the video doesn't re-appear if there's an error after the ajax call.
			this.set("opuslinkRegCodeExample", false);
			this.startLinkQuery("link", regCode);
		},
		
		onOpusLinkRefresh() {
			if (this.get("opuslinkAjaxPending")) {
				return;
			}
			this.setErrorMessage(null);
			this.startLinkQuery("refresh");
		},

		// TODO: Remove this once done testing.
		onOpusLinkClearLocal() {
			this.startLinkQuery("clearlocal");
		}
	},
});
