import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/features/profile/presentation/state/profile_controller.dart';

Widget profileApp(ProfileController c, Widget child,
        {double textScale = 1,
        EdgeInsets insets = EdgeInsets.zero,
        bool previewFont = false}) =>
    ProfileScope(
        controller: c,
        child: MaterialApp(
          theme: previewFont
              ? buildAppTheme().copyWith(
                  textTheme: buildAppTheme()
                      .textTheme
                      .apply(fontFamily: 'ProfilePreview'),
                  appBarTheme: buildAppTheme().appBarTheme.copyWith(
                      titleTextStyle: AppTextStyles.heading
                          .copyWith(fontFamily: 'ProfilePreview')),
                  filledButtonTheme: FilledButtonThemeData(
                      style: buildAppTheme().filledButtonTheme.style!.copyWith(
                          textStyle: WidgetStatePropertyAll(AppTextStyles
                              .bodyStrong
                              .copyWith(fontFamily: 'ProfilePreview')))),
                  textButtonTheme: TextButtonThemeData(
                      style: buildAppTheme().textButtonTheme.style!.copyWith(
                          textStyle: WidgetStatePropertyAll(AppTextStyles
                              .bodyStrong
                              .copyWith(fontFamily: 'ProfilePreview')))),
                )
              : buildAppTheme(),
          locale: const Locale('vi'),
          supportedLocales: const [Locale('vi')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          onGenerateRoute: onGenerateRoute,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale), viewInsets: insets),
              child: child!),
          home: Scaffold(body: child),
        ));
