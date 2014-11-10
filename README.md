draw-tangram
============

Draw Tangram figures in SVG format giving a simple description
of the lines in plain text.

Usage
-----

To run this program you need `perl` installed. Then you must create a text
file in the format explained below to describe a Tangram figure, and then run
the program from the command-line console, for example:

    perl draw-tangram.pl figure.txt > figure.svg

To see the resulting image you can drag and drop the SVG file in any modern web
browser or open it with any other application capable of view or edit SVG files.

The program can generate other views of the same figure, for example
to fill the pieces so you cannot view the lines:

    perl draw-tangram.pl -s FILLED figure.txt > figure.svg

Run `perl draw-tangram.pl` to see all options supported by the program.

Format
------

To describe a Tangram figure for the program you need to describe each piece
separately, and to describe a piece the position of its vertices must be given.

### Lengths ###

To give the position of each vertice of a piece you need to know the lengths
of the lines connecting these vertices, and know it for each piece of the
Tangram:

    .----------.---------.
    |        .'        .'|
    |      .'        .'  |
    |    .'--------.'    |
    |  .' '.     .'      |
    |.'     '. .'        |
    | '.     .'.         |
    |   '. .'   '.       |
    |    .'       '.     |
    |  .'           '.   |
    |.'               '. |
    '--------------------'

First consider that every side of the *square piece* has a length of 1. Then
you can calculate the lengths of the lines of all Tangram's pieces, and you
will find lengths like *1* or *2* but also lengths equal to the
*square root of 2*, or two times that number.

To represent lengths like these in the program, you can write the length
with two numbers separated by a colon, as in `NUM1:NUM2`, and the program
will multiply automatically the second number by the *square root of 2* and
the result will be added to the first number, so a length of *square root of 2*
is written as `0:1` and two times that number is written as `0:2`.

Using this convention, the lengths of the sides of all Tangram's pieces are:

* Square: side=`1`
* Small Triangles: side=`1`, hypotenuse=`0:1`
* Medium Triangle: side=`0:1`, hypotenuse=`2`
* Big Triangles: side=`2`, hypotenuse=`0:2`
* Parallelogram: small side=`1`, large side=`0:1`

### Angles and lines ###

To describe a line of a piece you need to give its length, but also its angle.
The angle is the direction of the line, and must be written with a number that
the program will multiply by *PI/4* radians (45 degrees). The angle `0` is the
horizontal direction from right to left and is incremented counterclockwise.
The basic angles to describe the lines of a piece are in the following diagram:

               . 2
     3 .--    /|\    --. 1
       |'.     |     .'|
          '.   |   .'
            '. | .'
    4 /_______' '_______\ 0
      \       . .       /
            .' | '.
          .'   |   '.
       |.'     |     '.|
     5 '--    \|/    --' 7
             6 '

A line is described by its angle and its length separated by a comma, and then
enclosed in square brackets, as in `[ANGLE,LENGTH]`, so the hypotenuse of
the above medium-sized triangle must be written as `[5,2]` or `[1,2]`.

### Pieces ###

To describe totally a piece, you must give a name for each vertice of the piece
and put between the names of every two vertices the description of the line that
connects them.  For example, the above medium-sized triangle can be written as:

    a [0,0:1] b [5,2] c [2,0:1] a;

And the result of passing this text to the program will be:

      .----------.
    a |        .' b
      |      .'
      |    .'
      |  .'
    c |.'

The last vertice must be equal to the first one because we are drawing a
closed polygon. The piece description must be always ended with a semicolon.

To describe another piece, you must begin with a vertice already used
in a previous piece, so every new piece must be added always in a position
relative to an existing piece. For example:

    a [0,0:1] b [5,2] c [2,0:1] a;
    b [0,0:1] d [5,1] e [4,0:1] f [1,1] b;

      .----------.---------.
    a |        .' b      .' d
      |      .'        .'
      |    .'--------.'
      |  .' f         e
    c |.'

### Hidden lines ###

Since not every piece connects with a vertice of another piece in Tangram
figures, we can add *hidden lines* ending in new vertices to draw other pieces
from them. Any piece description not ending in the same vertice on which it
begins will be a *hidden line* and will not be shown, but their vertices
can be used to draw other pieces. For example, to add a new piece not starting
from a previous vertice first we need to add a *hidden line* (here `a-g` line):

    a [0,0:1] b [5,2] c [2,0:1] a;
    b [0,0:1] d [5,1] e [4,0:1] f [1,1] b;
    a [0,1] g;
    g [1,1] h [7,1] i [4,0:1] g;

                   . h
                 .' '.
             g .'     '. i
      .-------'--.------'--.
    a |        .' b      .' d
      |      .'        .'
      |    .'--------.'
      |  .' f         e
    c |.'

### Rotation ###

If the angles of the lines of a piece in a Tangram figure are different than
the basic angles, you can describe the piece using the basic angles and then
give a special angle to rotate all the lines of the piece. This angle must be
before the description of the piece and enclosed between angle brackets,
as in `<ANGLE>`, for example:

    <1> a [0,0:1] b [5,2] c [2,0:1] a;
    <1> b [0,0:1] d [5,1] e [4,0:1] f [1,1] b;
    <1> a [0,1] g;
    <1> g [1,1] h [7,1] i [4,0:1] g;

         h      i  .| d
          .------.' |
          |    .'   |
          |  .'     | 
        g |.'| b   .' e
         .'  |   .'
    a  .'    | .'
     .'      |'
      '.     | f
        '.   |
          '. |
            '| c

The program also supports fractional angles and lengths, using the format
`+-NUM1/NUM2`, as in `-1/2`. Numbers with the decimal point are not permitted
to avoid the use of inexact numbers in the specification of the figures and
enable rational calculations and comparisons in future versions of the program.

