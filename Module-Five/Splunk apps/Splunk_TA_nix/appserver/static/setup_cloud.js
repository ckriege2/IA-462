/*
 * SPDX-FileCopyrightText: 2021 Splunk, Inc. <sales@splunk.com>
 * SPDX-License-Identifier: LicenseRef-Splunk-8-2021
 *
 */

require([
    'splunkjs/ready!',
    'jquery'
], function (mvc, $) {
    var service = mvc.createService()
    var cleaned_data = {}
    // Save button
    $('#save-btn').click(function (e) {
        e.preventDefault()
        if ($('#save-btn').hasClass('disabled')) {
            return
        }

        //Set is_configured=true in app.conf
        service.post('/services/SetupService', cleaned_data, function (
            err,
            response
        ) {
            if (err) {
                console.log('Error saving configuration in app.conf')
            }
            else {
                // Save successful. Provide feedback in form of page reload.
                window.location.reload()
            }
        })
    })
})
