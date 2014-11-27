draw-tangram
============

Draws Tangram figures in SVG format giving a simple description
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

Run `perl draw-tangram.pl` without parameters to see all options supported
by the program.

Format
------

To describe a Tangram figure for the program you need to describe each piece
separately, and to describe a piece the position of its vertices must be given.

### Lengths ###

To give the position of each vertice of a piece you need to know the *lengths*
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

### Angles ###

To describe a line of a piece you need to give its length, but also its *angle*.
The angle is the direction of the line, and must be written with a number that
the program will multiply by *PI/4* radians (45 degrees). The angle `0` is the
horizontal direction from left to right and is incremented counterclockwise.
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

The hypotenuse of the above medium-sized triangle can be written as `5` or `1`.

### Pieces ###

To describe totally a piece, first you must give a *name* for each vertice of
the piece and write all the *names* separated by hyphens in the order that these
vertices are connected by lines, repeating the first name at the last position,
for example `a-b-c-a`. Second, you must write the *angles* of these lines
separated by commas in the same order and enclosed in angle brackets,
as in `<0,5,2>`. Third, write the *lengths* of these lines separated by commas
in the same order and enclosed in square brackets, as in `[0:1,2,0:1]`.
For example, the above medium-sized triangle can be written as:

    a-b-c-a <0,5,2> [0:1,2,0:1];

And the result of passing this text to the program will be:

      .----------.
    a |        .' b
      |      .'
      |    .'
      |  .'
    c |.'

The last vertice must be equal to the first one because we are drawing a
closed polygon, and the number of angles and lengths must be equal to the
number of hyphens in the list of vertices. The piece description must be
always ended with a semicolon.

To describe another piece, you must begin with a vertice already used
in a previous piece, so every new piece must be added always in a position
relative to an existing piece. For example:

    a-b-c-a <0,5,2> [0:1,2,0:1];
    b-d-e-f-b <0,5,4,1> [0:1,1,0:1,1];

      .----------.---------.
    a |        .' b      .' d
      |      .'        .'
      |    .'--------.'
      |  .' f         e
    c |.'

An alternative extended notation using separated elements is also supported:

    a <0>[0:1] b <5>[2] c <2>[0:1] a;
    b <0>[0:1] d <5>[1] e <4>[0:1] f <1>[1] b;

### Hidden lines ###

Since not every piece connects with a vertice of another piece in Tangram
figures, we can add *hidden lines* ending in new vertices to draw other pieces
from them. Any piece description not ending in the same vertice on which it
begins will be a *hidden line* and will not be shown, but their vertices
can be used to draw other pieces. For example, to add a new piece not starting
from a previous vertice first we need to add a *hidden line* (here `a-g` line):

    a-b-c-a <0,5,2> [0:1,2,0:1];
    b-d-e-f-b <0,5,4,1> [0:1,1,0:1,1];
    a-g <0> [1];
    g-h-i-g <1,7,4> [1,1,0:1];

                   . h
                 .' '.
             g .'     '. i
      .-------'--.------'--.
    a |        .' b      .' d
      |      .'        .'
      |    .'--------.'
      |  .' f         e
    c |.'

The program also supports *relative angles* to make easier writing the pieces.
A *relative angle* is an angle describing an increment from the previous angle.
By inserting the `@` sign before the first angle in the description of a piece
all the angles of the piece except the first one will be considered
*relative angles*. For example, the previous figure described with them can be:

    a-b-c-a <@0,5,5> [0:1,2,0:1];
    b-d-e-f-b <@0,5,7,5> [0:1,1,0:1,1];
    a-g <0> [1];
    g-h-i-g <@1,6,5> [1,1,0:1];

### Rotation ###

If the angles of the lines of a piece in a Tangram figure are different than
the basic angles, you can describe the piece using the basic angles and then
give a special angle to rotate all the lines of the piece. This angle must be
before the description of the piece and enclosed between angle brackets,
as in `<ANGLE>`, for example:

    a-b-c-a <0,5,2> [0:1,2,0:1];
    b-d-e-f-b <0,5,4,1> [0:1,1,0:1,1];
    a-g <0> [1];
    <1/2> g-h-i-g <1,7,4> [1,1,0:1];

                h .
                 / ''-.
                /   .-'' i
             g /.-''
      .-------'--.---------.
    a |        .' b      .' d
      |      .'        .'
      |    .'--------.'
      |  .' f         e
    c |.'

The program supports fractional angles and lengths, using the format
`+-NUM1/NUM2`, as in `1/2`. Numbers with the decimal point are not permitted
to avoid the use of inexact numbers in the specification of the figures and
enable rational calculations and comparisons in future versions of the program.

To write comments in the file or hide lines temporarily, the program ignores
all text starting with the number sign `#` until the end of the line.

