package de.benibela.videlibri;

import android.app.Activity;
import android.content.Context;
import android.os.Build;
import android.support.v4.app.FragmentTransaction;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.*;
import android.widget.*;

import java.text.DateFormat;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.Iterator;

public class BookListActivity extends VideLibriBaseActivity{
    boolean port_mode;

    BookListFragment list;
    BookDetails details;
    View detailsPortHolder, listPortHolder;

    boolean portInDetailMode;
    int currentBookPos;
    int listFirstItem;
    ArrayList<Integer> selectedBooksIndices;

    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Log.d("VL", "onCreate: " + port_mode);
        setVideLibriView(R.layout.booklistactivity);
        port_mode = getResources().getBoolean(R.bool.port_mode);
        list = new BookListFragment(this);
        details = new BookDetails(this);

        if (savedInstanceState != null) {
            portInDetailMode = savedInstanceState.getBoolean("portInDetailMode");
            currentBookPos = savedInstanceState.getInt("currentBookPos");
            listFirstItem = savedInstanceState.getInt("listFirstItem");
            selectedBooksIndices = savedInstanceState.getIntegerArrayList("selectedBooksIndices");
        }

        if (port_mode) {
            detailsPortHolder = findViewById(R.id.bookdetailslayout);
            listPortHolder = findViewById(R.id.booklistlayout);
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        port_mode = getResources().getBoolean(R.bool.port_mode); //should not have changed
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        outState.putBoolean("portInDetailMode", portInDetailMode);
        outState.putInt("currentBookPos", currentBookPos);
        if (listFirstItem == 0) {
            //only use new position, if there is no old position.
            //when the device rotates too fast, the activity is recreated (here), before the listview is initialized
            ListView bookListView = (ListView) findViewById(R.id.booklistview);
            if (bookListView != null) listFirstItem = bookListView.getFirstVisiblePosition();
        }
        outState.putInt("listFirstItem", listFirstItem); //perhaps better use the list view save/restore state function??

        if (selectedBooks != null) {
            ArrayList<Integer> selindices = new ArrayList<Integer>(selectedBooks.size());
            for (int i = 0; i < selectedBooks.size(); i++)
                for (int j = 0; j < bookCache.size(); j++)
                    if (selectedBooks.get(i) == bookCache.get(j))
                        selindices.add(j);
            outState.putIntegerArrayList("selectedBooksIndices", selindices);
        }
    }

    public void onBookCacheAvailable(){
        //Log.d("VideLIBRI", "onBookCacheAvailable" + currentBookPos + " / " + listFirstItem + " / " + bookCache.size() );
        if (selectedBooksIndices != null) {
            if (selectedBooks == null) selectedBooks = new ArrayList<Bridge.Book>();
            for (int i = 0; i < selectedBooksIndices.size(); i++)
                selectedBooks.add(bookCache.get(selectedBooksIndices.get(i)));
            selectedBooksIndices = null;
            ((BookOverviewAdapter)((ListView) findViewById(R.id.booklistview)).getAdapter()).notifyDataSetChanged();
        }
        if (port_mode) {
            if (portInDetailMode && currentBookPos >= 0 && currentBookPos < bookCache.size()) showDetails(currentBookPos);
            else showList();
        } else showDetails(currentBookPos);
        final ListView bookListView = (ListView) findViewById(R.id.booklistview);
        bookListView.post(new Runnable() {
            @Override
            public void run() {
                if ( listFirstItem > 0)
                    bookListView.setSelectionFromTop(listFirstItem,0);
                listFirstItem = 0;
            }
        });
    }

    public ArrayList<Bridge.Book> bookCache = new ArrayList<Bridge.Book>();
    public EnumSet<BookOverviewAdapter.DisplayEnum> options = java.util.EnumSet.of(BookOverviewAdapter.DisplayEnum.Grouped, BookOverviewAdapter.DisplayEnum.ShowRenewCount);
    public String sortingKey, groupingKey;

    public ArrayList<Bridge.Book> selectedBooks = null;

    public Button bookActionButton = null; //set from detail fragment

    boolean cacheShown = false;

    void setOption(BookOverviewAdapter.DisplayEnum option, boolean on){
        if (on) options.add(option);
        else options.remove(option);
    }

    void displayBookCache(int partialSize){
        //Log.i("VL","Book count: "+partialSize);
        setOption(BookOverviewAdapter.DisplayEnum.Grouped, !"".equals(groupingKey));
        BookOverviewAdapter sa = new BookOverviewAdapter(this, bookCache, partialSize, options);
        ListView bookListView = (ListView) findViewById(R.id.booklistview);
        bookListView.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> adapterView, View view, int i, long l) {
                if (i >= bookCache.size() || bookCache.get(i) == null) return;
                if (groupingKey != "") {
                    Bridge.Book book = bookCache.get(i);
                    if (BookFormatter.isGroupingHeaderFakeBook(book)) return; //grouping header
                }
                viewDetails(i);
            }
        });
        bookListView.setAdapter(sa);
        if (!cacheShown) {
            cacheShown = true;
            onBookCacheAvailable();
        }
    }
    void displayBookCache(){
        displayBookCache(bookCache.size());
    }

    void updateDisplayBookCache(){
        ListView bookListView = (ListView) findViewById(R.id.booklistview);
        BookOverviewAdapter sa = (BookOverviewAdapter) bookListView.getAdapter();
        sa.setBooks(bookCache);
    }

    public void onPlaceHolderShown(int position){}


    public void viewDetails(int bookpos){
        showDetails(bookpos);
    }

    public void showDetails(int bookpos){
        if (bookpos < 0 || bookpos >= bookCache.size()) return;
        while (BookFormatter.isGroupingHeaderFakeBook(bookCache.get(bookpos))) {
            bookpos++;
            if (bookpos >= bookCache.size()) return;
        }
        currentBookPos = bookpos;
        if (port_mode) {
            detailsPortHolder.setVisibility(View.VISIBLE);
            listPortHolder.setVisibility(View.INVISIBLE);
            portInDetailMode = true;
        }
        details.setBook(bookCache.get(bookpos));
    }

    @Override
    protected int onPrepareOptionsMenuVisibility() {
        return ACTIONBAR_MENU_SHARE;
    }

    @Override
    public boolean onOptionsItemIdSelectedOld(Activity context, int id) {
        switch (id){
            case R.id.share: {
                Intent sendIntent = new Intent();
                sendIntent.setAction(Intent.ACTION_SEND);
                sendIntent.putExtra(Intent.EXTRA_TEXT,
                        (listVisible() ? list.exportShare(false) + "\n\n" : "")
                        + (detailsVisible() ? details.exportShare(false) + "\n\n" : "")
                        + tr(R.string.share_export_footer)
                );
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN)
                    sendIntent.putExtra(Intent.EXTRA_HTML_TEXT,
                            (listVisible() ? list.exportShare(true) + "<br>\n<br>\n" : "")
                            + (detailsVisible() ? details.exportShare(true) + "<br>\n<br>\n" : "")
                            + tr(R.string.share_export_footer)
                    );
                sendIntent.setType("text/plain");
                startActivity(Intent.createChooser(sendIntent, getResources().getText(R.string.menu_share)));
                return true;
            }
        }
        return super.onOptionsItemIdSelectedOld(context, id);
    }

    Object contextMenuSelectedItem;
    @Override
    public void onCreateContextMenu(ContextMenu menu, View v, ContextMenu.ContextMenuInfo menuInfo) {
        super.onCreateContextMenu(menu, v, menuInfo);
        MenuInflater inflater = getMenuInflater();
        inflater.inflate(R.menu.detailcontextmenu, menu);
        if (v instanceof ListView && menuInfo instanceof AdapterView.AdapterContextMenuInfo){
            ListView lv = (ListView) v;
            AdapterView.AdapterContextMenuInfo acmi = (AdapterView.AdapterContextMenuInfo) menuInfo;
            contextMenuSelectedItem = lv.getItemAtPosition(acmi.position);
        }
    }

    @Override
    public boolean onContextItemSelected(MenuItem item) {
        String toCopy = null;
        switch (item.getItemId()) {
            case R.id.copy:
                toCopy = contextMenuSelectedItem != null ? contextMenuSelectedItem.toString() : "";
                break;
            case R.id.copyall:
                if (!detailsVisible() || contextMenuSelectedItem instanceof Bridge.Book )
                    toCopy = list.exportShare(false);
                else if (contextMenuSelectedItem instanceof BookDetails.Details)
                    toCopy = details.exportShare(false);
                else
                    toCopy = list.exportShare(false) + "\n\n" + details.exportShare(false); //this case should not happen
                break;
        }
        if (toCopy != null) {
            if(android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.HONEYCOMB) {
                android.text.ClipboardManager clipboard = (android.text.ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
                clipboard.setText(toCopy);
            } else {
                android.content.ClipboardManager clipboard = (android.content.ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
                android.content.ClipData clip = android.content.ClipData.newPlainText("Book details", toCopy);
                clipboard.setPrimaryClip(clip);
            }
            Toast.makeText(this, tr(R.string.clipboard_copiedS, toCopy), Toast.LENGTH_SHORT).show();
        }
        contextMenuSelectedItem = null;
        return super.onContextItemSelected(item);
    }

    //shows the list. returns if the list was already visible
    public boolean showList(){
        if (!port_mode) return true;
        if (detailsVisible()) {
            listPortHolder.setVisibility(View.VISIBLE);
            detailsPortHolder.setVisibility(View.INVISIBLE);
            portInDetailMode = false;
            return false;
        } else return true;
    }
    public boolean detailsVisible(){
        if (!port_mode) return true;
        return detailsPortHolder.getVisibility() == View.VISIBLE;
    }
    public boolean listVisible(){
        if (!port_mode) return true;
        return !detailsVisible();
    }

    @Override
    public void onBackPressed() {
        if (showList())
            super.onBackPressed();
    }

    public void onBookActionButtonClicked(Bridge.Book book){} //called from detail fragment

}
