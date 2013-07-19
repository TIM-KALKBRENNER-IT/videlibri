package de.benibela.videlibri;


import android.app.Activity;
import android.content.Intent;
import android.graphics.Paint;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.Spinner;
import android.widget.TextView;
import com.actionbarsherlock.view.Menu;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Stack;

public class Search extends VideLibriBaseActivity implements Bridge.SearchConnector{
    static final int REQUEST_CHOOSE_LIBRARY = 1234;
    static ArrayList< Bridge.SearcherAccess> searchers = new ArrayList<Bridge.SearcherAccess>();

    private Bridge.SearcherAccess createSearcher(){
        Bridge.SearcherAccess searcher = new Bridge.SearcherAccess(this, libId);
        searchers.add(searcher);
        return searcher;
    }

    static void removeSearcherOwner(Object owner){
        if (searchers.isEmpty()) return;
        for (int i=searchers.size()-1; i >= 0; i--) {
            Bridge.SearcherAccess current = searchers.get(i);
            if (current.connector == owner) current.connector = null;
            if (current.display == owner) current.setDisplay(null);
            if (current.connector == null && current.display == null && !current.waitingForDisplay) {
                current.free();
                searchers.remove(i);
            }
        }
    }

    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.searchlayout);

        libId = getIntent().getStringExtra("libId");
        libName = getIntent().getStringExtra("libName");

        TextView lib = ((TextView) findViewById(R.id.library));
        lib.setText(libName);
        lib.setPaintFlags(lib.getPaintFlags() | Paint.UNDERLINE_TEXT_FLAG);
        if (libId == null || libId.equals("") || getIntent().getBooleanExtra("showLibList", false)) changeSearchLib();
        else {
            setLoading(true);
            createSearcher();
        }

        ((TextView) findViewById(R.id.library)).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                changeSearchLib();
            }
        });

        ((Button) findViewById(R.id.button)).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if (searchers.isEmpty() || searchers.get(searchers.size()-1).connector != Search.this)
                    createSearcher();
                searchers.get(searchers.size()-1).waitingForDisplay = true;

                Intent intent = new Intent(Search.this, SearchResult.class);
                Bridge.Book book = new Bridge.Book();
                book.title = getTextViewText(R.id.title);
                book.author = getTextViewText(R.id.author);
                book.setProperty("keywords", getTextViewText(R.id.keywords));
                book.setProperty("year", getTextViewText(R.id.year));
                book.setProperty("isbn", getTextViewText(R.id.isbn));
                intent.putExtra("searchQuery", book);
                if (findViewById(R.id.homeBranchLayout).getVisibility() != View.GONE)
                    intent.putExtra("homeBranch", ((Spinner)findViewById(R.id.homeBranch)).getSelectedItemPosition());
                if (findViewById(R.id.searchBranchLayout).getVisibility() != View.GONE)
                    intent.putExtra("searchBranch", ((Spinner)findViewById(R.id.searchBranch)).getSelectedItemPosition());
                startActivity(intent);
            }
        });

        setTitle("Katalog-Suche");
    }

    @Override
    public boolean onPrepareOptionsMenu(Menu menu) {
        boolean x= super.onPrepareOptionsMenu(menu);
        menu.findItem(R.id.search).setVisible(false);
        return x;
    }

    @Override
    protected void onDestroy() {
        removeSearcherOwner(this);
        super.onDestroy();
    }

    String libId, libName;

    void changeSearchLib(){
        Intent intent = new Intent(this, LibraryList.class);
        intent.putExtra("defaultLibId", libId);
        intent.putExtra("reason", "Wählen Sie die Bibliothek, in der Sie suchen wollen:");
        intent.putExtra("search", true);
        startActivityForResult(intent, REQUEST_CHOOSE_LIBRARY);
    }

    void setBranchViewes( String[] homeBranches, String[] searchBranches) {
        if (homeBranches == null || homeBranches.length == 0)
            findViewById(R.id.homeBranchLayout).setVisibility(View.GONE);
        else {
            findViewById(R.id.homeBranchLayout).setVisibility(View.VISIBLE);
            ArrayAdapter<String> adapter = new ArrayAdapter<String>(Search.this, android.R.layout.simple_spinner_item, homeBranches);
            adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
            ((Spinner) findViewById(R.id.homeBranch)).setAdapter(adapter);
        }
        if (searchBranches == null || searchBranches.length == 0)
            findViewById(R.id.searchBranchLayout).setVisibility(View.GONE);
        else {
            findViewById(R.id.searchBranchLayout).setVisibility(View.VISIBLE);
            ArrayAdapter<String> adapter = new ArrayAdapter<String>(Search.this, android.R.layout.simple_spinner_item, searchBranches);
            adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
            ((Spinner) findViewById(R.id.searchBranch)).setAdapter(adapter);
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == REQUEST_CHOOSE_LIBRARY) {
            if (resultCode == LibraryList.RESULT_OK){
                libId = data.getStringExtra("libId");
                libName = data.getStringExtra("libName");
                ((TextView) findViewById(R.id.library)).setText(libName);


                setLoading(true);
                removeSearcherOwner(this);
                createSearcher();
            }
        } else super.onActivityResult(requestCode, resultCode, data);
    }

    @Override
    public void onConnected(final String[] homeBranches, final String[] searchBranches) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                setLoading(false);
                setBranchViewes(homeBranches,searchBranches);
            }
        });
    }

    @Override
    public void onException() {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                setLoading(false);
                //setTitle("Katalog ist nicht erreichbar");
                Bridge.PendingException[] exceptions = Bridge.VLTakePendingExceptions();
                for (Bridge.PendingException ex : exceptions)
                    showMessage(ex.accountPrettyNames + ": " + ex.error);
                VideLibriApp.errors.addAll(Arrays.asList(exceptions));
            }
        });
    }
}