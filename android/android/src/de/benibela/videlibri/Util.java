package de.benibela.videlibri;

import android.app.AlertDialog;
import android.app.Dialog;
import android.content.ClipData;
import android.content.Context;
import android.content.DialogInterface;
import android.content.res.Resources;
import android.os.Bundle;
import android.support.annotation.NonNull;
import android.support.v4.app.DialogFragment;
import android.support.v7.app.AppCompatActivity;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.EditText;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import java.text.DateFormat;
import java.util.Date;
import java.util.IllegalFormatException;

import static android.content.Context.CLIPBOARD_SERVICE;

@SuppressWarnings({"WeakerAccess"})
public class Util {
    static int MessageHandlerCanceled = -123;
    static public String tr(int id){
        if (VideLibriApp.currentContext() == null) return "?tr?"+id;
        else return tr(VideLibriApp.currentContext(), id);
    }
    static public String tr(int id, Object... args){
        Context context = VideLibriApp.currentContext();
        if (context == null) return "?tr?" + id;
        try {
            return context.getString(id, args);
        } catch (Resources.NotFoundException e) {
            return "missing translation: "+id;
        } catch (IllegalFormatException e) {
            return context.getString(id);
        }
    }
    static public String tr(Context context, int id){
        try {
            return context.getString(id);
        } catch (Resources.NotFoundException e) {
            return "missing translation: "+id;
        }
    }
    static public String tr(Context context, int id, Object... args){
        try {
            return context.getString(id, args);
        } catch (Resources.NotFoundException e) {
            return "missing translation: "+id;
        } catch (IllegalFormatException e) {
            return context.getString(id);
        }
    }
    static public String[] tr(Context context, int[] ids){
        String[] res = new String[ids.length];
        for (int i=0;i<ids.length;i++)
            res[i] = tr(context, ids[i]);
        return res;
    }
    static public String[] trs(Object ids){
        if (ids == null) return null;
        if (ids instanceof String[]) return (String[]) ids;
        else {
            Context context = VideLibriApp.currentContext();
            if (context != null && ids instanceof int[]) return tr(context, (int[])ids);
        }
        return new String[]{};
    }

    public interface ViewIterator{
        void visit(View v);
    }
    static public void iterateChildViews(View view, ViewIterator iterator){
        iterator.visit(view);
        if (view instanceof ViewGroup) {
            ViewGroup g = (ViewGroup)view;
            for (int i=0;i<g.getChildCount();i++)
                iterateChildViews(g.getChildAt(i), iterator);
        }
    }

    static public boolean equalStrings(String s, String t) {
        return s == null ? t == null : s.equals(t);
    }

    public static boolean isEmptyString(String s) {
        return s == null || "".equals(s);
    }

    public static class DialogFragmentUtil extends DialogFragment implements DialogInterface.OnClickListener, DialogInterface.OnCancelListener{

        EditText edit;
        @NonNull
        @Override
        public Dialog onCreateDialog(Bundle savedInstanceState) {
            Bundle args = getArguments();
            int special = args.getInt("special");
            final String message = args.getString("message");
            String title = args.getString("title");
            String negative = args.getString("negativeButton");
            String neutral = args.getString("neutralButton");
            String positive = args.getString("positiveButton");
            String items[] = trs(args.get("items"));

            AlertDialog.Builder builder = new AlertDialog.Builder(getActivity());
            if (title != null) builder.setTitle(title);
            switch (special) {
                case DialogId.SPECIAL_LIBRARY_NOT_IN_LIST: {
                    if (message != null) {
                        String[] itemscopied = new String[items.length + 1];
                        itemscopied[0] = message;
                        for (int i = 0; i < items.length; i++) itemscopied[i + 1] = items[i];
                        items = itemscopied;
                    }
                    final boolean skipFirst = message != null;
                    final String itemsSubCaptions[] = trs(args.get("itemsSubCaption"));
                    LayoutInflater inflater = getActivity().getLayoutInflater();
                    View v = inflater.inflate(R.layout.dialogbooklistlike, null);
                    //((TextView) v.findViewById(R.id.textView)).setText(message);
                    ListView lv = (ListView) v.findViewById(R.id.listView);
                    lv.setAdapter(new ArrayAdapter<String>(getActivity(), R.layout.bookoverview, R.id.bookoverviewCaption, items) {
                                      @NonNull
                                      @Override
                                      public View getView(int position, View convertView, @NonNull ViewGroup parent) {
                                          View res = super.getView(position, convertView, parent);
                                          if (res != null) {
                                              res.findViewById(R.id.bookoverviewDate).setVisibility(View.GONE);
                                              if (skipFirst) {
                                                  if (position > 0) position--;
                                                  else {
                                                      res.findViewById(R.id.bookoverviewCaption).setVisibility(View.GONE);
                                                      TextView moreview = ((TextView) res.findViewById(R.id.bookoverviewMore));
                                                      moreview.setVisibility(View.VISIBLE);
                                                      moreview.setText(message);
                                                      return res;
                                                  }
                                              }
                                              res.findViewById(R.id.bookoverviewCaption).setVisibility(View.VISIBLE);
                                              ((TextView) res.findViewById(R.id.bookoverviewMore)).setText(position < itemsSubCaptions.length ? itemsSubCaptions[position] : "");
                                          }
                                          return res;
                                      }
                                  }
                    );
                    lv.setOnItemClickListener(new AdapterView.OnItemClickListener() {
                        @Override
                        public void onItemClick(AdapterView<?> adapterView, View view, int i, long l) {
                            if (skipFirst) i--;
                            if (i < 0) return;
                            notifyActivity(i);
                            dismiss();
                        }
                    });
                    builder.setView(v);

                    break;
                }
                case DialogId.SPECIAL_INPUT_DIALOG:
                    if (message != null)
                        builder.setMessage(message);
                    edit = new EditText(getActivity());
                    String def = args.getString("editTextDefault");
                    if (def != null) edit.setText(def);
                    builder.setView(edit);
                    break;
                default:
                    if (message != null)
                        builder.setMessage(message);
                    if (items != null)
                        builder.setItems(items, this);
            }
            if (negative != null)
                builder.setNegativeButton(negative, this);
            if (neutral != null)
                builder.setNeutralButton(neutral, this);
            if (positive != null)
                builder.setPositiveButton(positive, this);
            builder.setOnCancelListener(this);
            return builder.create();
        }

        @Override
        public void onClick(DialogInterface dialogInterface, int i) {
            notifyActivity(i);
        }

        @Override
        public void onCancel(DialogInterface dialog) {
            notifyActivity(MessageHandlerCanceled);
        }

        private void notifyActivity(int code){
            if (!(getActivity() instanceof VideLibriBaseActivity)) {
                Log.d("VideLibri", "No activity for dialog result");
                return;
            }
            Bundle args = getArguments();
            int myId = args.getInt("id");
            Log.d("VideLibri", "Dialog result "+code + " for "+ myId);
            Bundle more = args.getBundle("more");
            if (edit != null) {
                if (more == null) more = new Bundle();
                more.putString("text", edit.getText().toString());
            }
            ((VideLibriBaseActivity)getActivity()).onDialogResult(myId, code, more);
        }
    }


    static public void showMessage(String message){ showMessage(message, null); }
    static public void showMessage(int dialogId, String message){ showMessage(dialogId, message, null); }
    static public void showMessageYesNo(int dialogId, String message){ showMessageYesNo(dialogId, message, null); }

    static public void showMessage(String message, Bundle more){ showMessage(DialogId.OK, message, null, tr(R.string.ok), null, more); }
    static public void showMessage(int dialogId, String message, Bundle more){ showMessage(dialogId, message, null, tr(R.string.ok), null, more); }
    static public void showMessageYesNo(int dialogId, String message, Bundle more){ showMessage(dialogId, message, tr(R.string.no), null, tr(R.string.yes), more); }
    static public void showMessage(int dialogId, String message, String negative, String neutral, String positive){ showMessage(dialogId, message, negative, neutral, positive, null); }
    static public void showMessage(int dialogId, String message, int negative, int neutral, int positive){ showMessage(dialogId, message, Util.tr(negative), Util.tr(neutral), Util.tr(positive), null); }
    static public void showMessage(int dialogId, String message, int negative, int neutral, int positive, Bundle more){ showMessage(dialogId, message, Util.tr(negative), Util.tr(neutral), Util.tr(positive), more); }
    static public void showMessageNegPos(int dialogId, String message, String negative, String positive){ showMessage(dialogId, message, negative, null, positive, null); }
    static public void showMessageNegPos(int dialogId, String message, int negative, int positive){ showMessage(dialogId, message, Util.tr(negative), null, Util.tr(positive), null); }

    static public void showMessage(int dialogId, String message, String negative, String neutral, String positive, Bundle more){
        Bundle args = new Bundle();
        args.putInt("id", dialogId);
        args.putString("message", message);
        args.putString("negativeButton", negative);
        args.putString("neutralButton", neutral);
        args.putString("positiveButton", positive);
        if (more != null)
            args.putBundle("more", more);
        showDialog(args);
    }

    static public void chooseDialog(int dialogId, String title, String[] options) { chooseDialog(dialogId, title, options, null); }
    static public void chooseDialog(int dialogId, String title, String[] options, Bundle more) {
        Bundle args = new Bundle();
        args.putInt("id", dialogId);
        args.putString("title", title);
        args.putStringArray("items", options);
        args.putBundle("more", more);
        showDialog(args);
    }
    //result in more bundle key "text". Failure button is Util.MessageHandlerCanceled
    static public void inputDialog(int dialogId, int title){ inputDialog(dialogId, tr(title), null); }
    static public void inputDialog(int dialogId, String title, String message){ inputDialog(dialogId, title, message, null); }
    static public void inputDialog(int dialogId, String title, String message, String editDefault){
        Bundle args = new Bundle();
        args.putInt("id", dialogId);
        args.putString("positiveButton", tr(R.string.ok));
        args.putString("title", title);
        args.putString("message", message);
        args.putString("editTextDefault", editDefault);
        args.putInt("special", DialogId.SPECIAL_INPUT_DIALOG);
        showDialog(args);
    }


    static void showDialog(Bundle args){
        if (VideLibriApp.currentActivity instanceof AppCompatActivity) showDialog((AppCompatActivity)VideLibriApp.currentActivity, args);
        else VideLibriApp.pendingDialogs.add(args);
    }
    static public void showDialog(AppCompatActivity activity, Bundle args){
        DialogFragmentUtil frag = new DialogFragmentUtil();
        frag.setArguments(args);
        //String tag = "dialog" + args.getInt("id");
        frag.show(activity.getSupportFragmentManager(), null);//tag);
    }



    public static int strToIntDef(String s, int i) {
        if (s == null) return i;
        try {
            return Integer.parseInt(s);
        } catch (NumberFormatException e) {
            return i;
        }
    }


    private static DateFormat dateFormatShort;
    private static DateFormat dateFormatFull;
    public static String formatDate(Date date){
        if (date == null) return "";
        if (dateFormatShort == null){
            if (VideLibriApp.currentContext() != null)
                dateFormatShort = android.text.format.DateFormat.getDateFormat(VideLibriApp.currentContext());
            else
                dateFormatShort = java.text.DateFormat.getDateInstance(DateFormat.SHORT);
        }
        if (dateFormatShort != null) return dateFormatShort.format(date);
        return date.getYear()+"-"+date.getMonth()+"-"+date.getDay();
    }

    public static String formatDateFull(Date date){
        if (date == null) return "";
        if (dateFormatFull == null) {
            dateFormatFull = java.text.DateFormat.getDateInstance(java.text.DateFormat.FULL);
            if (dateFormatFull == null && VideLibriApp.currentContext() != null)
                dateFormatFull = android.text.format.DateFormat.getLongDateFormat(VideLibriApp.currentContext());
        }
        if (dateFormatFull != null) return dateFormatFull.format(date);
        return formatDate(date);
    }


    public static int compare(int a, int b) {
        if (a < b) return -1;
        else if (b < a) return 1;
        else return 0;
    }
    public static int compare(boolean a, boolean b) {
        if (a == b) return 0;
        if (a) return 1;
        return -1;
    }
    public static int   compareNullFirst(Object a, Object b) {
        return compare(a != null, b != null);
    }




    static class Clipboard{
        static CharSequence getText(Context context){
            if(android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.HONEYCOMB) {
                android.text.ClipboardManager cm = ((android.text.ClipboardManager) context.getSystemService(CLIPBOARD_SERVICE));
                if (cm == null) return null;
                return cm.getText();
            } else {
                android.content.ClipboardManager cm = ((android.content.ClipboardManager)context.getSystemService(CLIPBOARD_SERVICE));
                if (cm == null) return null;
                ClipData data = cm.getPrimaryClip();
                if (data == null) return null;
                ClipData.Item i = data.getItemAt(0);
                if (i == null) return null;
                return i.coerceToText(context);
            }
        }
        static void setText(Context context, CharSequence toCopy){
            if(android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.HONEYCOMB) {
                android.text.ClipboardManager clipboard = (android.text.ClipboardManager) context.getSystemService(Context.CLIPBOARD_SERVICE);
                if (clipboard == null) return;
                clipboard.setText(toCopy);
            } else {
                android.content.ClipboardManager clipboard = (android.content.ClipboardManager) context.getSystemService(Context.CLIPBOARD_SERVICE);
                if (clipboard == null) return;
                android.content.ClipData clip = android.content.ClipData.newPlainText("Book details", toCopy);
                if (clip == null) return;
                clipboard.setPrimaryClip(clip);
            }
            Toast.makeText(context, tr(R.string.clipboard_copiedS, toCopy), Toast.LENGTH_SHORT).show();

        }
    }
}
