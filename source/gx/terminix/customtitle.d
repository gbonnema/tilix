/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.customtitle;

import std.experimental.logger;

import gdk.Event;
import gdk.Keysyms;

import glib.Timeout;

import gobject.Value;

import gtk.Entry;
import gtk.EventBox;
import gtk.Label;
import gtk.Settings;
import gtk.Stack;
import gtk.Widget;

import gtkc.glib;

import gx.gtk.util;
import gx.i18n.l10n;

import gx.terminix.common;
import gx.terminix.constants;

/**
 * Custom title for AppWindow that allows the user
 * to click on the label in the headerbar and edit
 * the application title directly. Note this feature
 * is not available when CSD is disabled.
 */
public class CustomTitle: Stack {

private:
    enum PAGE_LABEL = "label";
    enum PAGE_EDIT = "edit";

    immutable bool CUSTOM_TIMEOUT = true;

    Entry eTitle;
    Label lblTitle;

    uint timeoutID;
    Timeout timeout;

    bool buttonDown;

    void createUI() {
        lblTitle = new Label(_(APPLICATION_NAME));
        lblTitle.getStyleContext().addClass("title");
        lblTitle.setEllipsize(PangoEllipsizeMode.START);
        EventBox eb = new EventBox();
        eb.add(lblTitle);
        eb.addOnButtonPress(&onButtonPress);
        eb.addOnButtonRelease(&onButtonRelease);
        addNamed(eb, PAGE_LABEL);

        eTitle = new Entry();
        eTitle.addOnKeyPress(delegate (Event event, Widget widget) {
            uint keyval;
            if (event.getKeyval(keyval)) {
                switch (keyval) {
                    case GdkKeysyms.GDK_Escape:
                        setVisibleChildName(PAGE_LABEL);
                        onCancelEdit.emit();
                        return true;
                    case GdkKeysyms.GDK_Return:
                        onTitleChange.emit(eTitle.getText());
                        setVisibleChildName(PAGE_LABEL);
                        return true;
                    default:
                }
            }
            return false;
        });
        eTitle.addOnFocusOut(delegate(Event event, Widget widget) {
            trace("Focus out");
            removeTimeout();
            setVisibleChildName(PAGE_LABEL);
            onCancelEdit.emit();
            return false;
        });
        addNamed(eTitle, PAGE_EDIT);
    }

    bool onButtonRelease(Event event, Widget widget) {
        trace("Button release");
        if (event.button.button != MouseButton.PRIMARY || !buttonDown) {
            tracef("Ignoring release %b", buttonDown);
            return false;
        }
        removeTimeout();

        Value value = new Value(500);
        getSettings().getProperty(GTK_DOUBLE_CLICK_TIME, value);
        uint doubleClickTime = value.getInt();
        trace("Create timeout");
        if (CUSTOM_TIMEOUT) {
            timeoutID = g_timeout_add(doubleClickTime, cast(GSourceFunc)&timeoutCallback, cast(void*)this);
            tracef("**** DoubleClickTime=%d, timeoutID=%d", doubleClickTime, timeoutID);
        } else {
            timeout = new Timeout(doubleClickTime, &onSingleClickTimer);
            tracef("**** DoubleClickTime=%d, timeoutID=%d", doubleClickTime, timeout.timeoutID);
        }

        buttonDown = false;
        return false;
    }

    bool onButtonPress(Event event, Widget widget) {
        if (event.button.button != MouseButton.PRIMARY) return false;

        if (event.getEventType() == EventType.DOUBLE_BUTTON_PRESS) {
            trace("Double click press");
            buttonDown = false;
            removeTimeout();
        } else {
            trace("Single click press");
            buttonDown = true;
        }
        return false;
    }

    bool onSingleClickTimer() {
        doEdit();
        return false;
    }

    void doEdit() {
        buttonDown = false;

        string value;
        CumulativeResult!string result = new CumulativeResult!string();
        onEdit.emit(result);
        if (result.getResults().length == 0) return;
        else value = result.getResults()[0];

        if (value.length > 0) {
            eTitle.setText(value);
        }
        setVisibleChildName(PAGE_EDIT);
        eTitle.grabFocus();
    }

    void removeTimeout() {
        if (CUSTOM_TIMEOUT) {
            if (timeoutID > 0) {
                g_source_remove(timeoutID);
                timeoutID = 0;
            }
        } else {
            if (timeout !is null) {
                trace("Removing timeout");
                //if (timeout.timeoutID > 0)
                timeout.stop();
                //timeout.destroy();
                timeout = null;
            }
        }
    }

	extern(C) static bool timeoutCallback(CustomTitle ct) {
        trace("Timeout callback received");
        ct.doEdit();
        ct.timeoutID = 0;
        return false;
	}

public:
    this() {
        super();
        createUI();
        addOnDestroy(delegate(Widget) {
            removeTimeout();
        });
    }

    @property string title() {
        return lblTitle.getText();
    }

    @property void title(string title) {
        lblTitle.setText(title);
    }

    GenericEvent!() onCancelEdit;

    GenericEvent!(CumulativeResult!string) onEdit;

    GenericEvent!(string) onTitleChange;
}
