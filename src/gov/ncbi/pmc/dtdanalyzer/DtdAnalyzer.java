/*
 * DtdAnalyzer.java
 */

package gov.ncbi.pmc.dtdanalyzer;

import org.apache.commons.cli.*;
import java.io.*;
import javax.xml.transform.*;
import javax.xml.transform.sax.*;
import javax.xml.transform.stream.*;
import org.apache.xml.resolver.tools.*;
import org.xml.sax.*;
import org.xml.sax.helpers.XMLReaderFactory;
import javax.xml.parsers.*;

/**
 * Creates XML representation of an XML DTD and then transforms it using
 * a provided stylesheet. This is a bare-bones application intended for
 * demonstration and debugging.
 */
public class DtdAnalyzer {
    
    private static App app;
    
    /**
     * Main execution point. Checks arguments, then converts the DTD into XML.
     * Once it has the XML, it transforms it using the specified XSL. The output
     * is placed in the specified location. Application currently uses Xerces and
     * Saxon because these are known to work well and will be bundled with this
     * distribution. However, other implementations can be specified through the
     * System properties.
     */
    public static void main (String[] args) {
      /*
        try {
            SAXParserFactory f = SAXParserFactory.newInstance();
            SAXParser commentParser = f.newSAXParser();
            
            InputSource xmlstr = new InputSource(new StringReader("<foo>bar</foo>"));
            DefaultHandler dh = new DefaultHandler();
            commentParser.parse(xmlstr, dh);
        }
        catch (Exception e) {
            System.err.println("Caught exception:  " + e.getMessage());
        }
        System.exit(0);
      */




        String[] optList = {
            "help", "doc", "system", "public", "catalog", "xslt", "title", "roots", "docproc",
            "markdown", "param"
        };
        app = new App(args, optList, 
            "dtdanalyzer [-h] [-d <xml-file> | -s <system-id> | -p <public-id>] " +
            "[-c <catalog>] [-x <xslt>] [-t <title>] [<out>]",
            "\nThis utility analyzes a DTD and writes an XML output file."
        );
        Options options = app.getActiveOpts();

        // Get the parsed command line arguments
        CommandLine line = app.getLine();
    
        // At least one of these must be given
        if (!line.hasOption("d") && !line.hasOption("s") && !line.hasOption("p")) {
            app.usageError("At least one of -d, -s, or -p must be specified!");
        }


        // There should be at most one thing left on the line, which, if present, specifies the
        // output file.
        Result out = null;
        String[] rest = line.getArgs();
        if (rest.length == 0) {
            out = new StreamResult(System.out);
        }
        else if (rest.length == 1) {
            out = new StreamResult(new File(rest[0]));            
        }
        else {
            app.usageError("Too many arguments!");
        }

        

        // Perform set-up and parsing here.  The output of this step is a fully chopped up
        // and recorded representation of the DTD, stored in the DtdEventHandler object.
        
        DTDEventHandler dtdEvents = new DTDEventHandler();
        try {
            XMLReader parser = XMLReaderFactory.createXMLReader();
            parser.setContentHandler(dtdEvents);
            parser.setErrorHandler(dtdEvents);
            parser.setProperty( "http://xml.org/sax/properties/lexical-handler", dtdEvents); 
            parser.setProperty( "http://xml.org/sax/properties/declaration-handler", dtdEvents);
            parser.setFeature("http://xml.org/sax/features/validation", true);
            
            // Resolve entities if we have a catalog
            CatalogResolver resolver = app.getResolver();
            if ( resolver != null ) parser.setEntityResolver(resolver); 
            
            // Run the parse to capture all events and create an XML representation of the DTD.
            // XMLReader's parse method either takes a system id as a string, or an InputSource
            if (line.hasOption("d")) {
                parser.parse(line.getOptionValue("d"));
            }
            else {
                parser.parse(app.getDummyXmlFile());
            }
        }

        catch (EndOfDTDException ede) {
            // ignore: this is a normal exception raised to signal the end of processing
        }
        
        catch (Exception e) {
            System.err.println( "Could not process the DTD.  Message from the parser:");
            System.err.println(e.getMessage());
            //e.printStackTrace();
            System.exit(1);
        }


        // The next step is to mung the data from the parsed DTD a bit, building derived
        // data structures.  The output of this step is stored in the ModelBuilder object.

        ModelBuilder model = new ModelBuilder(dtdEvents, app.getDtdTitle());
        String[] roots = app.getRoots();
        try {
            if (roots != null) model.findReachable(roots);
        }
        catch (Exception e) {
            // This is not fatal.
            System.err.println("Error trying to find reachable nodes from set of roots: " +
                e.getMessage());
        }
        XMLWriter writer = new XMLWriter(model);


        // Now run the XSLT transformation.  This defaults to the identity transform, if
        // no XSLT was specified.

        try {
            InputStreamReader reader = writer.getXML();
            
            Transformer xslt = app.getXslt();
            
            String[] xsltParams = app.getXsltParams();
            int numXsltParams = xsltParams.length / 2;
            if (numXsltParams > 0) {
                for (int i = 0; i < numXsltParams; ++i) {
                    xslt.setParameter(xsltParams[2*i], xsltParams[2*i+1]);
                }
            }
            
            // Use this constructor because Saxon always 
            // looks for a system id even when a reader is used as the source  
            // If no string is provided for the sysId, we get a null pointer exception
            Source xmlSource = new StreamSource(reader, "");
            xslt.transform(xmlSource, out);
        }

        catch (Exception e){ 
            System.err.println("Could not run the transformation: " + e.getMessage());
            e.printStackTrace(System.out);
        }     
    }
}