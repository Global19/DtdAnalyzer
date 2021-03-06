<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0"
                xmlns:np="http://ncbi.gov/portal/XSLT/namespace"
                xmlns:str="http://exslt.org/strings"
                xmlns:f="http://exslt.org/functions"
                xmlns:c="http://exslt.org/common"
                extension-element-prefixes="c np str f">

  <!-- Turn off pretty-printing by setting this to false() -->
  <xsl:param name='pretty' select='true()'/>

  <!-- By default, do not convert all names to lowercase -->
  <xsl:param name='lcnames' select='false()'/>

  <!-- $nl == the newline character -->
  <xsl:variable name='nl' select='"&#10;"'/>


  <!-- $nlp == newline when pretty-printing; otherwise empty string  -->
  <xsl:variable name='nlp'>
    <xsl:choose>
      <xsl:when test='$pretty'>
        <xsl:value-of select='$nl'/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select='""'/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- $iu = indent unit (four spaces) when pretty-printing;
       otherwise empty string -->
  <xsl:variable name='iu'>
    <xsl:choose>
      <xsl:when test='$pretty'>
        <xsl:value-of select='"    "'/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select='""'/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>



  <!--================================================
    Utility templates and functions
  -->

  <!--
    Convert a string to lowercase
  -->

  <xsl:variable name="lo" select="'abcdefghijklmnopqrstuvwxyz'"/>
  <xsl:variable name="hi" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ'"/>

  <f:function name='np:lower-case'>
    <xsl:param name='s'/>
    <f:result>
      <xsl:value-of select="translate($s, $hi, $lo)"/>
    </f:result>
  </f:function>

  <!--
    Converts the name of the current context element or attribute
    into lowercase, only if the $lcnames param is true.
  -->
  <xsl:template name="np:translate-name">
    <xsl:param name="s" select='name(.)'/>
    <xsl:choose>
      <xsl:when test='$lcnames'>
        <xsl:value-of select="np:lower-case($s)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select='$s'/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <f:function name="np:translate-name">
    <xsl:param name="s" select='name(.)'/>
    <f:result>
      <xsl:call-template name="np:translate-name">
        <xsl:with-param name="s" select="$s"/>
      </xsl:call-template>
    </f:result>
  </f:function>

  <!--
    Quote a string to prepare it for insertion into a JSON literal value.
  -->
  <xsl:template name='json-escape-with-replace'>
    <xsl:param name="s"/>
    <xsl:text>&quot;</xsl:text>
    <xsl:value-of
      select="str:replace(
                str:replace(
                  str:replace(
                    str:replace(
                      str:replace($s,
                        '\', '\\'
                      ),
                      '&quot;', '\&quot;'
                    ),
                    '&#10;', '\n'
                  ),
                  '&#13;', '\r'
                ),
                '&#9;', '\t'
              )"/>
    <xsl:text>&quot;</xsl:text>
  </xsl:template>

  <xsl:template name='replace-char'>
    <xsl:param name="s"/>
    <xsl:param name="c"/>
    <xsl:param name="r"/>

    <xsl:choose>
      <xsl:when test='contains($s, $c)'>
        <xsl:value-of select='concat(substring-before($s, $c), $r)'/>
        <xsl:call-template name='replace-char'>
          <xsl:with-param name="s" select="substring-after($s, $c)"/>
          <xsl:with-param name="c" select='$c'/>
          <xsl:with-param name="r" select='$r'/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select='$s'/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!--
    mkey = member key - this produces a string which is the key in double-quotes,
    followed by a colon, space.  It is used whenever outputting a member of a JSON
    object.
  -->
  <f:function name='np:mkey'>
    <xsl:param name='k'/>
    <f:result>
      <xsl:value-of select="concat('&quot;', $k, '&quot;: ')"/>
    </f:result>
  </f:function>

  <!--
    This function takes a boolean indicating whether or not we want a trailing
    comma.  If false, it returns the empty string; if true, a comma.  It's like
    the ternary-operator expression ($trailing-comma ? "," : "").
  -->
  <f:function name='np:tc'>
    <xsl:param name='trailing-comma'/>
    <f:result>
      <xsl:if test='$trailing-comma'>
        <xsl:text>,</xsl:text>
      </xsl:if>
    </f:result>
  </f:function>


  <!--
    The following three return the json-escaped values for simple types
  -->
  <f:function name='np:string-value'>
    <xsl:param name='v'/>
    <f:result>
      <xsl:call-template name='json-escape-with-replace'>
        <xsl:with-param name="s" select='$v'/>
      </xsl:call-template>
    </f:result>
  </f:function>

  <f:function name='np:strip-leading-zeros'>
    <xsl:param name='n'/>
    <f:result>
      <xsl:choose>
        <xsl:when test="starts-with($n, '0')">
          <xsl:value-of select="np:strip-leading-zeros(substring($n, 2))"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$n"/>
        </xsl:otherwise>
      </xsl:choose>
    </f:result>
  </f:function>

  <f:function name='np:number-value'>
    <xsl:param name='v'/>
    <xsl:variable name='nsv' select='normalize-space($v)'/>
    <f:result>
      <xsl:choose>
        <xsl:when test='starts-with($nsv, "0") and not(starts-with($nsv, "0."))'>
          <xsl:value-of select='np:strip-leading-zeros($nsv)'/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select='$nsv'/>
        </xsl:otherwise>
      </xsl:choose>
    </f:result>
  </f:function>

  <f:function name='np:boolean-value'>
    <xsl:param name='v'/>
    <xsl:variable name='nv' select='np:lower-case(normalize-space($v))'/>
    <f:result>
      <xsl:choose>
        <xsl:when test='$nv = "0" or $nv = "no" or $nv = "n" or $nv = "false" or
          $nv = "f" or $nv = "off" or $nv = ""'>
          <xsl:text>false</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>true</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </f:result>
  </f:function>

  <!--============================================================
    Generic templates
  -->

  <!--
    Default template for the document root node.  This generates the outermost
    JSON object and the header.
  -->

  <!--
    Don't override this template that matches "/" in your custom stylesheets.
    Instead, override the template named "root", which generates jxml.
  -->
  <xsl:template match="/">
    <xsl:variable name='jxml'>
      <xsl:call-template name='root'/>
    </xsl:variable>
    <!--<xsl:copy-of select='$jxml'/>-->
    <xsl:variable name='jxml-ns' select='c:node-set($jxml)'/>
    <xsl:apply-templates select='$jxml-ns/*' mode='serialize-jxml-array'/>
  </xsl:template>


  <xsl:template name='root'>
    <xsl:param name='header-strings'
      select='c:node-set($dtd-annotation)/json'/>

    <o>
      <xsl:if test='$header-strings'>
        <xsl:call-template name='header'>
          <xsl:with-param name='header-strings' select='$header-strings'/>
        </xsl:call-template>
      </xsl:if>
      <xsl:apply-templates select='*'>
        <xsl:with-param name="context" select="'o'"/>
      </xsl:apply-templates>
    </o>
  </xsl:template>

  <xsl:template name='header'>
    <xsl:param name='header-strings'/>

    <o k='header'>
      <xsl:for-each select='$header-strings/@*'>
        <s k='{name(.)}'>
          <xsl:value-of select='.'/>
        </s>
      </xsl:for-each>
    </o>
  </xsl:template>

  <!--
    s
    There are separate template here for when we don't know the context
    ("s") or when we do ("s-in-o", "s-in-a").
  -->
  <xsl:template name='s'>
    <xsl:param name='context' select='"unknown"'/>
    <xsl:param name='k'>
      <xsl:choose>
        <xsl:when test='self::text()'>
          <xsl:text>value</xsl:text>
        </xsl:when>
        <xsl:otherwise>  <!-- This is an attribute or element node -->
          <xsl:value-of select='np:translate-name()'/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:param name='value' select='.'/>

    <xsl:choose>
      <xsl:when test='$context = "o"'>
        <s k='{$k}'>
          <xsl:value-of select='$value'/>
        </s>
      </xsl:when>
      <xsl:when test='$context = "a"'>
        <s>
          <xsl:value-of select='$value'/>
        </s>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message>
          <xsl:text>Error:  context is not defined for element </xsl:text>
          <xsl:value-of select='name(.)'/>
          <xsl:text> ($context = "</xsl:text>
          <xsl:value-of select='$context'/>
          <xsl:text>", $k = "</xsl:text>
          <xsl:value-of select='$k'/>
          <xsl:text>")</xsl:text>
        </xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!--
    s-in-o
    This translates the node into a key:value pair.  If it's a text node, then, by
    default, the key will be "value".  If it's an attribute or element node, then,
    by default, the key will be the name converted to lowercase (it's up to you
    to make sure they are unique within the object).
  -->
  <xsl:template name='s-in-o'>
    <xsl:param name='k'>
      <xsl:choose>
        <xsl:when test='self::text()'>
          <xsl:text>value</xsl:text>
        </xsl:when>
        <xsl:otherwise>  <!-- This is an attribute or element node -->
          <xsl:value-of select='np:translate-name()'/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:param name='value' select='.'/>

    <s k='{$k}'>
      <xsl:value-of select='$value'/>
    </s>
  </xsl:template>

  <!--
    s-in-a
    For text nodes, attributes, or elements that have simple content, when
    in the context of a JSON array.  This discards the attribute or element name,
    and produces a quoted string from the content.
  -->
  <xsl:template name='s-in-a'>
    <xsl:param name='value' select='.'/>
    <s>
      <xsl:value-of select='$value'/>
    </s>
  </xsl:template>

  <!--
    n
    Delegates either to n-in-o or n-in-a.
  -->
  <xsl:template name='n'>
    <xsl:param name='context' select='"unknown"'/>
    <xsl:param name='k'>
      <xsl:choose>
        <xsl:when test='self::text()'>
          <xsl:text>value</xsl:text>
        </xsl:when>
        <xsl:otherwise>  <!-- This is an attribute or element node -->
          <xsl:value-of select='np:translate-name()'/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:param name='value' select='.'/>

    <xsl:choose>
      <xsl:when test='$context = "o"'>
        <n k='{$k}'>
          <xsl:value-of select='np:number-value($value)'/>
        </n>
      </xsl:when>
      <xsl:when test='$context = "a"'>
        <n>
          <xsl:value-of select='np:number-value($value)'/>
        </n>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message>
          <xsl:text>Error:  context is not defined for element </xsl:text>
          <xsl:value-of select='name(.)'/>
          <xsl:text> ($context = "</xsl:text>
          <xsl:value-of select='$context'/>
          <xsl:text>", $k = "</xsl:text>
          <xsl:value-of select='$k'/>
          <xsl:text>")</xsl:text>
        </xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>


  <!--
    n-in-o
    For text nodes, attributes, or elements that have simple
    content, when in the context of a JSON object.
  -->
  <xsl:template name='n-in-o'>
    <xsl:param name='k'>
      <xsl:choose>
        <xsl:when test='self::text()'>
          <xsl:text>value</xsl:text>
        </xsl:when>
        <xsl:otherwise>  <!-- This is an attribute or element node -->
          <xsl:value-of select='np:translate-name()'/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:param name='value' select='.'/>

    <n k='{$k}'>
      <xsl:value-of select='np:number-value($value)'/>
    </n>
  </xsl:template>

  <!--
    n-in-a
    For text nodes, attributes, or elements that have simple content, when
    in the context of a JSON array.  This discards the attribute or element name,
    and produces a quoted string from the content.
  -->
  <xsl:template name='n-in-a'>
    <xsl:param name='value' select='.'/>
    <n>
      <xsl:value-of select='np:number-value($value)'/>
    </n>
  </xsl:template>


  <!--
    b
    Delegates either to b-in-o or b-in-a.
  -->
  <xsl:template name='b'>
    <xsl:param name='context' select='"unknown"'/>
    <xsl:param name='k'>
      <xsl:choose>
        <xsl:when test='self::text()'>
          <xsl:text>value</xsl:text>
        </xsl:when>
        <xsl:otherwise>  <!-- This is an attribute or element node -->
          <xsl:value-of select='np:translate-name()'/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:param name='value' select='.'/>

    <xsl:choose>
      <xsl:when test='$context = "o"'>
        <b k='{$k}'>
          <xsl:value-of select='np:boolean-value($value)'/>
        </b>
      </xsl:when>
      <xsl:when test='$context = "a"'>
        <b>
          <xsl:value-of select='np:boolean-value($value)'/>
        </b>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message>
          <xsl:text>Error:  context is not defined for element </xsl:text>
          <xsl:value-of select='name(.)'/>
          <xsl:text> ($context = "</xsl:text>
          <xsl:value-of select='$context'/>
          <xsl:text>", $k = "</xsl:text>
          <xsl:value-of select='$k'/>
          <xsl:text>")</xsl:text>
        </xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!--
    b-in-o
    For text nodes, attributes, or elements that have simple
    content, when in the context of a JSON object.
  -->
  <xsl:template name='b-in-o'>
    <xsl:param name='k'>
      <xsl:choose>
        <xsl:when test='self::text()'>
          <xsl:text>value</xsl:text>
        </xsl:when>
        <xsl:otherwise>  <!-- This is an attribute or element node -->
          <xsl:value-of select='np:translate-name()'/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:param name='value' select='.'/>

    <b k='{$k}'>
      <xsl:value-of select='np:boolean-value($value)'/>
    </b>
  </xsl:template>

  <!--
    b-in-a
    For text nodes, attributes, or elements that have simple content, when
    in the context of a JSON array.  This discards the attribute or element name,
    and produces a quoted string from the content.
  -->
  <xsl:template name='b-in-a'>
    <xsl:param name='value' select='.'/>

    <b>
      <xsl:value-of select='np:boolean-value($value)'/>
    </b>
  </xsl:template>


  <!--
    a
    Delegates either to a-in-o or a-in-a.
  -->
  <xsl:template name='a'>
    <xsl:param name='context' select='"unknown"'/>
    <xsl:param name='k' select='""'/>
    <xsl:param name='kids' select='*'/>

    <xsl:choose>
      <xsl:when test='$context = "o" and $k = ""'>
        <xsl:call-template name='a-in-o'>
          <xsl:with-param name='kids' select='$kids'/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test='$context = "o" and $k != ""'>
        <xsl:call-template name='a-in-o'>
          <xsl:with-param name='k' select='$k'/>
          <xsl:with-param name='kids' select='$kids'/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test='$context = "a"'>
        <xsl:call-template name="a-in-a">
          <xsl:with-param name='kids' select='$kids'/>
        </xsl:call-template>
      </xsl:when>

      <xsl:when test='$context = "o"'>
        <xsl:message>
          <xsl:text>Error:  bad key passed in for element </xsl:text>
          <xsl:value-of select='name(.)'/>
        </xsl:message>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message>
          <xsl:text>Error:  context is not defined for element </xsl:text>
          <xsl:value-of select='name(.)'/>
          <xsl:text> ($context = "</xsl:text>
          <xsl:value-of select='$context'/>
          <xsl:text>", $k = "</xsl:text>
          <xsl:value-of select='$k'/>
          <xsl:text>")</xsl:text>
        </xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>


  <!--
    a-in-o
    Call this template for array-type elements.  That is, usually, elements
    whose content is a list of child elements with the same name.
    By default, the key will be the name converted to lowercase.
    This produces a JSON array.  The "kids" are the set of child elements only,
    so attributes and text node children are discarded.
  -->
  <xsl:template name='a-in-o'>
    <xsl:param name='k' select='np:translate-name()'/>
    <xsl:param name='kids' select='*'/>

    <a k='{$k}'>
      <xsl:apply-templates select='$kids'>
        <xsl:with-param name='context' select='"a"'/>
      </xsl:apply-templates>
    </a>
  </xsl:template>

  <!--
    a-in-a
    Array-type elements that occur inside other arrays.
  -->
  <xsl:template name='a-in-a'>
    <xsl:param name='k' select='np:translate-name()'/>
    <xsl:param name='kids' select='*'/>

    <a>
      <xsl:apply-templates select='$kids'>
        <xsl:with-param name='context' select='"a"'/>
      </xsl:apply-templates>
    </a>
  </xsl:template>


  <!--
    o
    Delegates either to o-in-o or o-in-a.
  -->
  <xsl:template name='o'>
    <xsl:param name='context' select='"unknown"'/>
    <xsl:param name='k' select='np:translate-name()'/>
    <xsl:param name='kids' select='@*|*'/>

    <xsl:choose>
      <xsl:when test='$context = "o"'>
        <o k='{$k}'>
          <xsl:apply-templates select='$kids'>
            <xsl:with-param name='context' select='"o"'/>
          </xsl:apply-templates>
        </o>
      </xsl:when>
      <xsl:when test='$context = "a"'>
        <o>
          <xsl:apply-templates select='$kids'>
            <xsl:with-param name='context' select='"o"'/>
          </xsl:apply-templates>
        </o>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message>
          <xsl:text>Error:  context is not defined for element </xsl:text>
          <xsl:value-of select='name(.)'/>
          <xsl:text> ($context = "</xsl:text>
          <xsl:value-of select='$context'/>
          <xsl:text>", $k = "</xsl:text>
          <xsl:value-of select='$k'/>
          <xsl:text>")</xsl:text>
        </xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>


  <!--
    o-in-o
    For elements that have attributes and/or heterogenous content.  These are
    converted into JSON objects.
    The key, by default, is taken from this element's name, converted to lowercase.
    By default, this recurses by calling apply-templates on all attributes and
    element children.  So text-node children are discarded.  You can override that
    by passing the $kids param.
  -->
  <xsl:template name='o-in-o'>
    <xsl:param name='k' select='np:translate-name()'/>
    <xsl:param name='kids' select='@*|*'/>

    <o k='{$k}'>
      <xsl:apply-templates select='$kids'>
        <xsl:with-param name='context' select='"o"'/>
      </xsl:apply-templates>
    </o>
  </xsl:template>

  <!--
    o-in-a
    For elements that contain heterogenous content.  These are converted
    into JSON objects.
  -->
  <xsl:template name='o-in-a'>
    <xsl:param name='kids' select='@*|*'/>
    <o>
      <xsl:apply-templates select='$kids'>
        <xsl:with-param name='context' select='"o"'/>
      </xsl:apply-templates>
    </o>
  </xsl:template>




  <!--
    Default template for an element or attribute.
    Reports a problem.
  -->
  <xsl:template match='@*|*'>
    <xsl:param name='context' select='"o"'/>

    <xsl:message>
      <xsl:text>FIXME:  No template defined for </xsl:text>
      <xsl:choose>
        <xsl:when test='self::*'>
          <xsl:text>element </xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>attribute </xsl:text>
          <xsl:value-of select='concat(name(..), "/@")'/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:value-of select='name(.)'/>
      <xsl:value-of select='concat(" (context = ", $context, ")")'/>
    </xsl:message>

    <xsl:choose>
      <xsl:when test='$context = "a"'>
        <xsl:call-template name='s-in-a'/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name='s-in-o'/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Default template for text nodes.  Throw them away if they
    are all blanks.  Report a problem otherwise.
    Let's not report a problem and see if that's okay.  See sample5, test45
    and following.
  -->
  <xsl:template match="text()" >
    <xsl:param name='context' select='"o"'/>

    <xsl:if test='normalize-space(.) != ""'>
    <!--
      <xsl:message>
        <xsl:text>FIXME:  non-blank text node with no template match.  Parent element: </xsl:text>
        <xsl:value-of select='name(..)'/>
      </xsl:message>
    -->
      <xsl:choose>
        <xsl:when test='$context = "a"'>
          <xsl:call-template name='s-in-a'/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name='s-in-o'/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
  </xsl:template>

  <!--=====================================================
    The following templates serialize jxml into JSON.
    These use mode to also encode the context:  either -object
    or -array.  I think this will probably give better
    performance than passing it down as a parameter.
  -->
  <xsl:template match='o' mode='serialize-jxml-array'>
    <xsl:param name='indent' select='""'/>

    <!--<xsl:value-of select='"{"'/>-->
    <xsl:value-of select='concat($indent, "{", $nlp)'/>
    <xsl:apply-templates select='*' mode='serialize-jxml-object'>
      <xsl:with-param name='indent' select='concat($indent, $iu)'/>
    </xsl:apply-templates>
    <xsl:value-of select='concat($indent, "}")'/>
    <xsl:if test='position() != last()'>
      <xsl:text>,</xsl:text>
    </xsl:if>    
    <xsl:value-of select='$nlp'/>
  </xsl:template>

  <xsl:template match='o' mode='serialize-jxml-object'>
    <xsl:param name='indent' select='""'/>

    <xsl:value-of select='concat($indent, np:mkey(@k), "{", $nlp)'/>
    <xsl:apply-templates select='*' mode='serialize-jxml-object'>
      <xsl:with-param name='indent' select='concat($indent, $iu)'/>
    </xsl:apply-templates>
    <xsl:value-of select='concat($indent, "}")'/>
    <xsl:if test='position() != last()'>
      <xsl:text>,</xsl:text>
    </xsl:if>
    <xsl:value-of select='$nlp'/>
  </xsl:template>

  <xsl:template match='a' mode='serialize-jxml-array'>
    <xsl:param name='indent' select='""'/>

    <xsl:value-of select='concat($indent, "[", $nlp)'/>
    <xsl:apply-templates select='*' mode='serialize-jxml-array'>
      <xsl:with-param name='indent' select='concat($indent, $iu)'/>
    </xsl:apply-templates>
    <xsl:value-of select='"]"'/>
    <xsl:if test='position() != last()'>
      <xsl:text>,</xsl:text>
    </xsl:if>    
  </xsl:template>

  <xsl:template match='a' mode='serialize-jxml-object'>
    <xsl:param name='indent' select='""'/>

    <xsl:value-of select='concat($indent, np:mkey(@k), "[", $nlp)'/>
    <xsl:apply-templates select='*' mode='serialize-jxml-array'>
      <xsl:with-param name='indent' select='concat($indent, $iu)'/>
    </xsl:apply-templates>
    <xsl:value-of select='concat($indent, "]")'/>
    <xsl:if test='position() != last()'>
      <xsl:text>,</xsl:text>
    </xsl:if>
    <xsl:value-of select='$nlp'/>
  </xsl:template>

  <xsl:template match='s|n|b' mode='serialize-jxml-array'>
    <xsl:param name='indent' select='""'/>

    <xsl:value-of select='$indent'/>
    <xsl:choose>
      <xsl:when test='. = "" or (name(.) != "n" and name(.) != "b")'>
        <xsl:call-template name='json-escape-with-replace'>
          <xsl:with-param name="s" select='.'/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select='.'/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:if test='position() != last()'>
      <xsl:text>,</xsl:text>
    </xsl:if>
    <xsl:value-of select='$nlp'/>
  </xsl:template>

  <xsl:template match='s|n|b' mode='serialize-jxml-object'>
    <xsl:param name='indent' select='""'/>

    <xsl:value-of select="concat($indent, '&quot;', @k, '&quot;: ')"/>
    <xsl:choose>
      <xsl:when test='. = "" or (name(.) != "n" and name(.) != "b")'>
        <xsl:call-template name='json-escape-with-replace'>
          <xsl:with-param name="s" select='.'/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select='.'/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:if test='position() != last()'>
      <xsl:text>,</xsl:text>
    </xsl:if>
    <xsl:value-of select='$nlp'/>
  </xsl:template>

  <!--=====================================================
    This last template is used in testing the output for consistency, and
    is enabled when the 'check-json' command line option is given.  It first
    generates the JXML, and then runs it, recursively, through the checker
    template with mode="check-jxml".
  -->
  <xsl:template name='check-json'>
    <xsl:variable name='jxml-v'>
      <xsl:call-template name="root"/>
    </xsl:variable>
    <xsl:variable name='jxml' select='c:node-set($jxml-v)/*'/>
    <xsl:for-each select='$jxml'>
      <xsl:apply-templates mode='check-jxml'/>
    </xsl:for-each>
    <xsl:apply-templates select='$jxml' mode='serialize-jxml-array'/>
  </xsl:template>

  <xsl:template match='*' mode='check-jxml'>
    <xsl:variable name='k' select='@k'/>
    <xsl:if test='$k = ""'>
      <xsl:message terminate="yes">Empty key found in JSON result!</xsl:message>
    </xsl:if>
    <xsl:if test='$k != "" and preceding-sibling::*[@k = $k]'>
      <xsl:message terminate="yes">Duplicate key found in JSON result!</xsl:message>
    </xsl:if>
    <xsl:apply-templates select='*' mode='check-jxml'/>
  </xsl:template>

</xsl:stylesheet>
