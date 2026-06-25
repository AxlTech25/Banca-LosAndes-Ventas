import 'package:flutter/material.dart';



import '../../../features/auth/models/auth_session.dart';

import '../../../features/credit_request/views/credit_request_list_view.dart';

import '../web_shell_widgets.dart';



class WebSolicitudesPage extends StatelessWidget {

  const WebSolicitudesPage({

    super.key,

    required this.session,

    this.initialTabIndex = 0,

  });



  final AuthSession session;

  final int initialTabIndex;



  @override

  Widget build(BuildContext context) {

    return WebEmbeddedTheme(

      child: CreditRequestListView(

        session: session,

        initialTabIndex: initialTabIndex,

        embedded: true,

      ),

    );

  }

}

